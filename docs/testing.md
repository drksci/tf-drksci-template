# Testing

## Layers

| Layer | Tool | When | Hardware needed |
|---|---|---|---|
| Static | `tofu fmt/validate`, shellcheck | Always | None |
| Plan | Terratest (Go) | `.tf` changes | None (no SSH) |
| Script | pytest + testcontainers | `.sh` changes | Docker |
| E2E | pytest + k8s client | Post-deploy | Live cluster |

## Running tests

```bash
# Static checks (fmt + validate + shellcheck)
mise run validate

# Script syntax only (instant)
mise run test-scripts-smoke

# Script execution in Ubuntu containers (requires Docker)
mise run test-scripts

# Terraform plan-level (no hardware)
mise run test-terraform

# All local tests
mise run test-all

# E2E against live cluster
KUBECONFIG=~/.kube/homelab.yaml mise run test-e2e
```

## Pytest marks

| Mark | Meaning |
|---|---|
| `smoke` | Fast, no Docker, no cluster — runs in CI always |
| `slow` | Requires Docker (testcontainers) or takes >30s |
| `e2e` | Requires live cluster (`KUBECONFIG` must be reachable) |

## E2E environment variables

| Variable | Default | Description |
|---|---|---|
| `KUBECONFIG` | `~/.kube/homelab.yaml` | Path to cluster kubeconfig |
| `INTERNAL_DOMAIN` | `drksci.local` | Internal DNS zone |
| `TRAEFIK_IP` | auto-detected | Traefik LB IP (override if detection fails) |
| `MINIO_ROOT_USER` | `admin` | MinIO access key |
| `MINIO_ROOT_PASSWORD` | — | MinIO secret key (required for S3 tests) |
| `ENABLE_ARGOCD` | — | Set to `true` to run ArgoCD tests |
| `ENABLE_REGISTRY` | — | Set to `true` to run registry tests |
| `ENABLE_BACKUP` | — | Set to `true` to run Velero tests |

## Trigger integration tests on GitHub

```bash
mise run test   # triggers workflow_dispatch on current branch
gh run watch    # stream the output
```
