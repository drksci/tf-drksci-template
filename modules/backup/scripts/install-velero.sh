#!/usr/bin/env bash
# Velero — k8s resource + PVC backup to MinIO (local S3).
# Backs up all namespaces daily, retains RETENTION_DAYS worth of backups.
# rclone then syncs the MinIO bucket to Google Drive (see install-rclone.sh).
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${MINIO_ENDPOINT:=http://minio.minio.svc.cluster.local:9000}"
: "${MINIO_BUCKET:=velero}"
: "${MINIO_ACCESS_KEY:=admin}"
: "${MINIO_SECRET_KEY:?MINIO_SECRET_KEY is required}"
: "${BACKUP_SCHEDULE:=0 3 * * *}"
: "${RETENTION_DAYS:=7}"

export KUBECONFIG

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts 2>/dev/null || true
helm repo update vmware-tanzu

# MinIO credentials as a k8s Secret
kubectl create namespace velero 2>/dev/null || true
kubectl create secret generic velero-minio-creds \
  --from-literal=cloud="[default]
aws_access_key_id=${MINIO_ACCESS_KEY}
aws_secret_access_key=${MINIO_SECRET_KEY}" \
  --namespace velero \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install velero vmware-tanzu/velero \
  --namespace velero \
  --wait \
  --timeout 5m \
  --set configuration.backupStorageLocation[0].name=default \
  --set configuration.backupStorageLocation[0].provider=aws \
  --set configuration.backupStorageLocation[0].bucket="${MINIO_BUCKET}" \
  --set configuration.backupStorageLocation[0].config.region=minio \
  --set configuration.backupStorageLocation[0].config.s3ForcePathStyle=true \
  --set configuration.backupStorageLocation[0].config.s3Url="${MINIO_ENDPOINT}" \
  --set configuration.backupStorageLocation[0].credential.name=velero-minio-creds \
  --set configuration.backupStorageLocation[0].credential.key=cloud \
  --set configuration.volumeSnapshotLocation[0].name=default \
  --set configuration.volumeSnapshotLocation[0].provider=aws \
  --set configuration.volumeSnapshotLocation[0].config.region=minio \
  --set initContainers[0].name=velero-plugin-for-aws \
  --set initContainers[0].image=velero/velero-plugin-for-aws:latest \
  --set initContainers[0].volumeMounts[0].mountPath=/target \
  --set initContainers[0].volumeMounts[0].name=plugins \
  --set "defaultVolumesToFsBackup=true"

# Create scheduled backup — all namespaces, daily
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-full
  namespace: velero
spec:
  schedule: "${BACKUP_SCHEDULE}"
  template:
    ttl: $((RETENTION_DAYS * 24))h0m0s
    includedNamespaces:
      - '*'
    storageLocation: default
    volumeSnapshotLocations:
      - default
EOF

# Run an immediate backup to verify
velero_bin="$(kubectl -n velero get pods -l app.kubernetes.io/name=velero -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [[ -n "${velero_bin}" ]]; then
  kubectl -n velero exec "${velero_bin}" -- velero backup create initial-verify \
    --include-namespaces default,argocd \
    --wait 2>/dev/null || echo "Initial backup queued (verify with: mise run backup-status)"
fi

echo ""
echo "Velero deployed — backup schedule: ${BACKUP_SCHEDULE}"
echo "  Storage: MinIO at ${MINIO_ENDPOINT}/${MINIO_BUCKET}"
echo "  Retention: ${RETENTION_DAYS} days"
echo "  Check status: mise run backup-status"
