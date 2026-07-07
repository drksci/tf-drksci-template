# Mise tasks reference

Run any task with `mise run <task>`. List all tasks: `mise run help`.

## Infrastructure

| Task | Description |
|---|---|
| `install` | Install / update all mise-managed tools to latest |
| `init` | `tofu init` — run once after clone |
| `plan` | `tofu plan` — preview changes |
| `deploy` | Full stack deploy (bootstrap → runtime → all modules) |
| `destroy` | Tear down all infrastructure (prompts for confirmation) |
| `output` | Print all Terraform outputs |
| `validate` | Static checks: `tofu fmt`, `tofu validate`, shellcheck |

## Cluster access

| Task | Description |
|---|---|
| `kubeconfig` | Fetch kubeconfig via SSH → `.kube/homelab.yaml` |
| `kubeconfig-tailscale` | Fetch kubeconfig via Tailscale (no SSH key needed) |
| `kubectl` | kubectl wrapper using homelab kubeconfig |
| `k9s` | Launch k9s (installs if absent) |
| `shell` | fzf pod picker → `kubectl exec -it` |
| `expose` | `SVC=x NS=y mise run expose` — patch Service to tailnet LoadBalancer |

## Node access

| Task | Description |
|---|---|
| `login` | Interactive SSH session (fzf node picker) |
| `user-create` | Create system user on a node |
| `user-list` | List non-system users on a node |

## Secrets

| Task | Description |
|---|---|
| `secrets-init` | Generate age keypair, patch `.sops.yaml` (run once) |
| `secrets-encrypt` | Encrypt `terraform.tfvars` → `terraform.tfvars.enc` |
| `secrets-decrypt` | Decrypt `terraform.tfvars.enc` → `terraform.tfvars` |

## Testing

| Task | Description |
|---|---|
| `test-scripts-smoke` | Fast script syntax checks (no Docker) |
| `test-scripts` | Script tests via testcontainers (requires Docker) |
| `test-terraform` | Terratest plan-level tests |
| `test-all` | All local tests: static + smoke + Terratest |
| `test` | Trigger integration workflow on GitHub Actions |
| `test-e2e` | E2E tests against live cluster (requires KUBECONFIG) |

## Dashboards

| Task | Description |
|---|---|
| `dashboard-open` | Print all service URLs |
| `argocd-password` | Print ArgoCD initial admin password |

## Dagger

| Task | Description |
|---|---|
| `dagger-connect` | Open SSH tunnel to remote Dagger engine |
| `dagger-status` | Check Dagger engine status on primary node |

## Backup

| Task | Description |
|---|---|
| `backup-auth` | Authenticate rclone with Google Drive (OAuth flow) |
| `backup-status` | Show recent Velero backup status |
| `backup-trigger` | Trigger an immediate Velero backup |
| `restore` | Interactive restore from a Velero backup |
| `retention-check` | Run PVC retention detector manually |

## Operations

| Task | Description |
|---|---|
| `runner-status` | Show GitHub Actions runner pod status |
| `expose-status` | Show public IngressRoutes and Tailscale Ingresses |
| `kubeshark` | Launch KubeShark eBPF network tap |
| `help` | List all available tasks |
