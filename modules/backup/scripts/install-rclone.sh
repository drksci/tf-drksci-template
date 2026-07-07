#!/usr/bin/env bash
# rclone → Google Drive sync for off-site backup.
# Deploys rclone as a k8s CronJob that syncs the Velero MinIO bucket to Google Drive.
#
# FIRST-TIME AUTH (one-time, on your Mac):
#   mise run backup-auth
#   → runs `rclone authorize "drive"` locally, opens your browser
#   → sign in to Google, allow rclone
#   → paste the printed token into terraform.tfvars as gdrive_rclone_token
#
# After that, backups run headlessly — token auto-refreshes.
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${MINIO_ENDPOINT:=http://minio.minio.svc.cluster.local:9000}"
: "${MINIO_BUCKET:=velero}"
: "${MINIO_ACCESS_KEY:=admin}"
: "${MINIO_SECRET_KEY:?MINIO_SECRET_KEY is required}"
: "${GDRIVE_RCLONE_TOKEN:?GDRIVE_RCLONE_TOKEN is required — run: mise run backup-auth}"
: "${GDRIVE_FOLDER_ID:=}"
: "${GDRIVE_SYNC_SCHEDULE:=0 4 * * *}"
: "${RETENTION_DAYS:=30}"

export KUBECONFIG

kubectl create namespace backup 2>/dev/null || true

# rclone config — stored as a k8s Secret
GDRIVE_ROOT="${GDRIVE_FOLDER_ID:+root_folder_id = ${GDRIVE_FOLDER_ID}}"

kubectl create secret generic rclone-config \
  --namespace backup \
  --from-literal=rclone.conf="
[minio]
type = s3
provider = Minio
access_key_id = ${MINIO_ACCESS_KEY}
secret_access_key = ${MINIO_SECRET_KEY}
endpoint = ${MINIO_ENDPOINT}
region = minio

[gdrive]
type = drive
scope = drive
token = ${GDRIVE_RCLONE_TOKEN}
${GDRIVE_ROOT}
" \
  --dry-run=client -o yaml | kubectl apply -f -

# CronJob: sync MinIO velero bucket → Google Drive, prune old copies
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rclone-gdrive-sync
  namespace: backup
spec:
  schedule: "${GDRIVE_SYNC_SCHEDULE}"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: rclone
            image: rclone/rclone:latest
            args:
            - sync
            - minio:${MINIO_BUCKET}
            - gdrive:homelab-backups
            - --config=/etc/rclone/rclone.conf
            - --transfers=4
            - --checkers=8
            - --min-age=1h
            - --log-level=INFO
            - --stats=5m
            volumeMounts:
            - name: rclone-config
              mountPath: /etc/rclone
              readOnly: true
            resources:
              requests:
                memory: 128Mi
                cpu: 50m
              limits:
                memory: 512Mi
          volumes:
          - name: rclone-config
            secret:
              secretName: rclone-config
EOF

echo ""
echo "rclone GDrive sync deployed — schedule: ${GDRIVE_SYNC_SCHEDULE}"
echo "  Source: MinIO s3://${MINIO_BUCKET}"
echo "  Dest:   Google Drive → homelab-backups/"
echo ""
echo "Run a manual sync now:"
echo "  mise run backup-sync-now"
