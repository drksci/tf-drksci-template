# Homelab End-to-End Tests

Live-cluster integration tests for the `drksci.local` homelab stack.

## Prerequisites

- Python 3.12+ with `uv` (installed by `mise`)
- A running k3s cluster reachable via kubeconfig
- `KUBECONFIG` pointing at a valid kubeconfig (default: `~/.kube/homelab.yaml`)
- For storage tests: MinIO credentials in env vars
- For service/backup tests: `ENABLE_<SERVICE>=true` env vars (see table below)

## How to run

### Via mise (recommended)

```sh
# Run all e2e tests (cluster must be reachable)
mise run test-e2e

# Run only smoke tests (no cluster needed)
cd tests/e2e && uv run pytest -m smoke -v

# Run a specific test file
cd tests/e2e && uv run pytest test_cluster.py -v

# Run slow tests (PVC provision, DNS pod, registry push)
cd tests/e2e && uv run pytest -m "e2e and slow" -v --timeout=300

# Run in parallel (4 workers)
cd tests/e2e && uv run pytest -m e2e -v -n 4
```

### Directly with pytest

```sh
cd tests/e2e
uv run pytest -m e2e -v
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `KUBECONFIG` | `~/.kube/homelab.yaml` | Path to kubeconfig |
| `INTERNAL_DOMAIN` | `drksci.local` | Base domain for internal services |
| `TRAEFIK_IP` | auto-detected | Traefik LoadBalancer IP (overrides cluster lookup) |
| `MINIO_ROOT_USER` | `admin` | MinIO / S3 access key |
| `MINIO_ROOT_PASSWORD` | _(required for S3 tests)_ | MinIO / S3 secret key |
| `ENABLE_ARGOCD` | `false` | Set to `true` to run ArgoCD tests |
| `ENABLE_REGISTRY` | `false` | Set to `true` to run registry tests |
| `ENABLE_LONGHORN` | `false` | Set to `true` to run Longhorn UI test |
| `ENABLE_PULSE` | `false` | Set to `true` to run Pulse UI test |
| `ENABLE_BACKUP` | `false` | Set to `true` to run Velero/backup tests |

## Marks

| Mark | Meaning |
|---|---|
| `smoke` | Fast checks, no live cluster needed |
| `e2e` | Requires a live cluster (`KUBECONFIG` must be set and reachable) |
| `slow` | Longer-running e2e tests: PVC provisioning, DNS pod, registry push/pull |

Tests tagged `e2e` **skip gracefully** when the cluster is unreachable —
they never fail with a connection error. Use `-m "e2e and not slow"` to skip
the slow tests in time-constrained environments.

## Test files

| File | What it covers |
|---|---|
| `test_cluster.py` | Node readiness, kube-system health, Traefik, secrets encryption, Longhorn DaemonSet |
| `test_storage.py` | MinIO S3 CRUD, auth enforcement, Longhorn StorageClass & RecurringJobs, PVC provisioning |
| `test_networking.py` | IngressRoute CRDs, MinIO via Traefik, in-cluster DNS resolution, dnsmasq detection |
| `test_services.py` | ArgoCD, registry, registry push/pull (docker CLI), Longhorn UI, Pulse UI |
| `test_backup.py` | Velero deployment, Schedule CRDs, retention-detector CronJob, backup bucket |
| `test_minio_e2e.py` | In-cluster S3 access (aws-cli pod), multipart upload, private bucket enforcement |

## Cleanup

All tests that create Kubernetes resources (PVCs, pods) use `try/finally`
teardown so orphaned resources are never left behind even on failure.
Temporary S3 buckets follow the same pattern.
