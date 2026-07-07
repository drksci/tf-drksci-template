#!/usr/bin/env bash
# Deploy Longhorn — distributed block storage for Kubernetes.
# Provides: volume management UI, snapshots, backups, HA replicas.
# Sets itself as the default StorageClass so PVCs use it automatically.
# https://longhorn.io/
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${LONGHORN_HOST:=longhorn.drksci.local}"
: "${REPLICA_COUNT:=1}"
: "${DATA_PATH:=/var/lib/longhorn}"

export KUBECONFIG

# Longhorn requires open-iscsi on every node
if command -v apt-get &>/dev/null; then
  apt-get install -y -qq open-iscsi nfs-common cryptsetup dmsetup 2>/dev/null || true
  systemctl enable --now iscsid 2>/dev/null || true
elif command -v dnf &>/dev/null; then
  dnf install -y iscsi-initiator-utils nfs-utils cryptsetup device-mapper 2>/dev/null || true
  systemctl enable --now iscsid 2>/dev/null || true
fi

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

helm repo add longhorn https://charts.longhorn.io 2>/dev/null || true
helm repo update longhorn

helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --wait \
  --timeout 5m \
  --set defaultSettings.defaultReplicaCount="${REPLICA_COUNT}" \
  --set defaultSettings.defaultDataPath="${DATA_PATH}" \
  --set persistence.defaultClass=true \
  --set persistence.defaultClassReplicaCount="${REPLICA_COUNT}" \
  --set ingress.enabled=false

# Traefik IngressRoute for Longhorn UI
kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: longhorn-ui
  namespace: longhorn-system
spec:
  entryPoints: [web]
  routes:
    - match: Host(\`${LONGHORN_HOST}\`)
      kind: Rule
      services:
        - name: longhorn-frontend
          port: 80
          namespace: longhorn-system
EOF

TRAEFIK_IP=$(kubectl get svc -n traefik traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<traefik-ip>")

echo ""
echo "Longhorn deployed at http://${LONGHORN_HOST}"
echo "  Default StorageClass: longhorn (replicas: ${REPLICA_COUNT})"
echo "  Volume data path:     ${DATA_PATH}"
echo "  Add to /etc/hosts:    ${TRAEFIK_IP} ${LONGHORN_HOST}"
echo "  PVCs now use Longhorn by default — no storageClassName needed in manifests."
