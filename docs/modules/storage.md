# Storage

Two storage systems: Longhorn for k8s PVCs, MinIO for S3-compatible object storage.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_storage` | bool | `true` | Deploy storage module |
| `enable_longhorn` | bool | `true` | Deploy Longhorn |
| `longhorn_hostname` | string | `longhorn.drksci.local` | Longhorn UI URL |
| `longhorn_replica_count` | number | `1` | Volume replicas (1 = single node, 2-3 = HA) |
| `longhorn_data_path` | string | `/var/lib/longhorn` | Host path for volume data |
| `longhorn_exposure` | string | `internal` | `internal` \| `tailnet` \| `public` |
| `enable_minio` | bool | `true` | Deploy MinIO |
| `minio_hostname` | string | `s3.drksci.local` | MinIO S3 API URL |
| `minio_console_hostname` | string | `minio.drksci.local` | MinIO console URL |
| `minio_root_user` | string | `admin` | MinIO root username |
| `minio_root_password` | string | — | MinIO root password (required) |
| `minio_data_path` | string | `/opt/minio/data` | Host path for object data |
| `minio_console_exposure` | string | `internal` | `internal` \| `tailnet` \| `public` |

## Longhorn

Deployed as a Helm chart in k3s. Becomes the default StorageClass — all PVCs use Longhorn automatically unless `storageClassName` is specified.

Recurring jobs (configured at deploy time):
- `daily-snapshot`: 02:00 UTC, retain 7 snapshots
- `weekly-backup`: 03:00 UTC Sunday, retain 4 backups

## MinIO

Runs as a **Docker Compose stack** (Dockge-managed), not inside k3s. This means:
- Survives k3s restarts independently
- Data at `minio_data_path` on the host filesystem
- Managed via Dockge UI at `dockge.drksci.local`

k8s workloads reach MinIO via a headless Service + Endpoints in the `minio` namespace:
```
minio.minio.svc.cluster.local:9000   # S3 API
minio.minio.svc.cluster.local:9001   # console
```

## AWS CLI example

```bash
aws --endpoint-url http://s3.drksci.local \
    --no-verify-ssl \
    s3 mb s3://my-bucket

aws --endpoint-url http://s3.drksci.local \
    s3 cp file.txt s3://my-bucket/
```
