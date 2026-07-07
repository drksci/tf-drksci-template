#!/usr/bin/env bash
# Deploy MinIO — S3-compatible object storage with web console.
# Single-node mode (homelab). Uses Longhorn PVC if available, else local-path.
# S3 API: http://s3.drksci.local  Console: http://minio.drksci.local
# https://min.io/
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${MINIO_HOST:=s3.drksci.local}"
: "${CONSOLE_HOST:=minio.drksci.local}"
: "${ROOT_USER:=admin}"
: "${ROOT_PASSWORD:?ROOT_PASSWORD is required (min 8 chars)}"
: "${STORAGE_SIZE:=100Gi}"

export KUBECONFIG

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

# Use Longhorn if available, otherwise fall back to local-path (k3s default)
STORAGE_CLASS=$(kubectl get storageclass longhorn 2>/dev/null | grep -q longhorn && echo "longhorn" || echo "local-path")
echo "Using StorageClass: ${STORAGE_CLASS}"

helm repo add minio https://charts.min.io/ 2>/dev/null || true
helm repo update minio

helm upgrade --install minio minio/minio \
  --namespace minio \
  --create-namespace \
  --wait \
  --timeout 3m \
  --set mode=standalone \
  --set rootUser="${ROOT_USER}" \
  --set rootPassword="${ROOT_PASSWORD}" \
  --set persistence.enabled=true \
  --set persistence.storageClass="${STORAGE_CLASS}" \
  --set persistence.size="${STORAGE_SIZE}" \
  --set resources.requests.memory=256Mi \
  --set service.type=ClusterIP \
  --set consoleService.type=ClusterIP \
  --set ingress.enabled=false \
  --set consoleIngress.enabled=false

# Traefik IngressRoutes — S3 API + web console on separate hostnames
kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: minio-api
  namespace: minio
spec:
  entryPoints: [web]
  routes:
    - match: Host(\`${MINIO_HOST}\`)
      kind: Rule
      services:
        - name: minio
          port: 9000
          namespace: minio
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: minio-console
  namespace: minio
spec:
  entryPoints: [web]
  routes:
    - match: Host(\`${CONSOLE_HOST}\`)
      kind: Rule
      services:
        - name: minio-console
          port: 9001
          namespace: minio
EOF

TRAEFIK_IP=$(kubectl get svc -n traefik traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<traefik-ip>")

echo ""
echo "MinIO deployed."
echo "  S3 API:    http://${MINIO_HOST}  (use as AWS_ENDPOINT_URL in clients)"
echo "  Console:   http://${CONSOLE_HOST}"
echo "  User:      ${ROOT_USER}"
echo "  Storage:   ${STORAGE_SIZE} on ${STORAGE_CLASS}"
echo ""
echo "  Add to /etc/hosts:"
echo "    ${TRAEFIK_IP} ${MINIO_HOST}"
echo "    ${TRAEFIK_IP} ${CONSOLE_HOST}"
echo ""
echo "  AWS CLI example:"
echo "    aws --endpoint-url http://${MINIO_HOST} s3 mb s3://my-bucket"
echo "    aws --endpoint-url http://${MINIO_HOST} s3 cp file.txt s3://my-bucket/"
