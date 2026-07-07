# Backup

Velero for k8s resource + PVC backups, rclone for sync to Google Drive, and a PVC retention detector CronJob.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_backup` | bool | `false` | Deploy backup stack |
| `enable_velero` | bool | `true` | Deploy Velero |
| `backup_schedule` | string | `0 3 * * *` | Cron schedule for Velero backups |
| `backup_retention_days` | number | `7` | Days to retain Velero backups |
| `enable_gdrive_sync` | bool | `false` | Enable rclone → Google Drive sync |
| `gdrive_rclone_token` | string | `""` | rclone OAuth token (run `mise run backup-auth`) |
| `gdrive_folder_id` | string | `""` | Google Drive folder ID |
| `enable_retention_detector` | bool | `true` | Deploy PVC retention alert CronJob |
| `retention_check_schedule` | string | `0 8 * * *` | When to run retention checks |
| `retention_alert_webhook` | string | `""` | Webhook URL for expiry alerts |

## What it deploys

- **Velero**: scheduled backups of all namespaces to MinIO S3 (`s3://backups`)
- **rclone**: syncs MinIO `backups` bucket to Google Drive (if enabled)
- **Retention detector**: CronJob that reads `retention.homelab/ttl` annotations on PVCs and fires webhook alerts 7 days before and at expiry — **never deletes anything**

## PVC retention annotation

```yaml
metadata:
  annotations:
    retention.homelab/ttl: "90d"   # supports d (days), m (months), y (years), "infinite"
```

## Longhorn recurring snapshots

Separate from Velero — configured in the Longhorn install:
- `daily-snapshot`: 02:00 UTC, retain 7
- `weekly-backup`: 03:00 UTC Sunday, retain 4

## Google Drive auth

```bash
mise run backup-auth   # opens OAuth flow, saves token to tfvars
```
