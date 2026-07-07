#!/usr/bin/env bash
# Deploy MinIO as a Docker Compose stack managed by Dockge.
# Runs alongside k3s on the host — not inside k3s — so it survives cluster restarts.
# k8s workloads reach it via an ExternalName Service → minio.minio.svc.cluster.local
# S3 API: http://MINIO_HOST   Console: http://CONSOLE_HOST
# https://min.io/
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${MINIO_HOST:=s3.drksci.local}"
: "${CONSOLE_HOST:=minio.drksci.local}"
: "${ROOT_USER:=admin}"
: "${ROOT_PASSWORD:?ROOT_PASSWORD is required (min 8 chars)}"
: "${MINIO_DATA_PATH:=/opt/minio/data}"
: "${STACKS_DIR:=/opt/stacks}"

export KUBECONFIG

# ---------------------------------------------------------------------------
# Docker Compose stack (deployed via Dockge)
# ---------------------------------------------------------------------------

STACK_DIR="${STACKS_DIR}/minio"
mkdir -p "${STACK_DIR}" "${MINIO_DATA_PATH}"

cat > "${STACK_DIR}/compose.yaml" <<EOF
services:
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: "${ROOT_USER}"
      MINIO_ROOT_PASSWORD: "${ROOT_PASSWORD}"
    volumes:
      - ${MINIO_DATA_PATH}:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

docker compose -f "${STACK_DIR}/compose.yaml" up -d
echo "MinIO container started"

# ---------------------------------------------------------------------------
# k8s Service + Endpoints pointing at the host node
# so pods can reach MinIO as minio.minio.svc.cluster.local:9000
# ---------------------------------------------------------------------------

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

# Resolve the node's primary IP as seen from within the cluster
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
[[ -n "${NODE_IP}" ]] || NODE_IP=$(hostname -I | awk '{print $1}')

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: minio
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
spec:
  clusterIP: None
  ports:
    - name: api
      port: 9000
    - name: console
      port: 9001
---
apiVersion: v1
kind: Endpoints
metadata:
  name: minio
  namespace: minio
subsets:
  - addresses:
      - ip: "${NODE_IP}"
    ports:
      - name: api
        port: 9000
      - name: console
        port: 9001
EOF

# ---------------------------------------------------------------------------
# Traefik IngressRoutes — S3 API + console
# ---------------------------------------------------------------------------

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
        - name: minio
          port: 9001
EOF

echo ""
echo "MinIO deployed (Docker Compose, managed by Dockge)."
echo "  Node IP:   ${NODE_IP}"
echo "  S3 API:    http://${MINIO_HOST}        (AWS_ENDPOINT_URL for clients)"
echo "  Console:   http://${CONSOLE_HOST}"
echo "  In-cluster: minio.minio.svc.cluster.local:9000"
echo "  User:      ${ROOT_USER}"
echo "  Data:      ${MINIO_DATA_PATH}"
echo ""
echo "  AWS CLI example:"
echo "    aws --endpoint-url http://${MINIO_HOST} s3 mb s3://my-bucket"
