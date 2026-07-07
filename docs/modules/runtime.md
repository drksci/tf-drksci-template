# Runtime

Installs the container runtime and Kubernetes distribution on each node.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `runtime` | string | `k3s` | `k3s` \| `colima` \| `microk8s` \| `podman` |
| `k8s_version` | string | `v1.30.5` | Kubernetes version |
| `container_runtime_interface` | string | `containerd` | `containerd` \| `crio` |
| `enable_gvisor` | bool | `true` | Install gVisor RuntimeClass |
| `enable_kata` | bool | `false` | Install Kata Containers RuntimeClass |

## What it deploys

### k3s (default)
- k3s server on primary with flags: `--secrets-encryption`, `--disable traefik`, `--disable servicelb`
- k3s agent on each worker node (joins via `K3S_URL=https://<primary>:6443`)
- Traefik deployed separately (not the built-in k3s Traefik)
- Token: `random_password` resource in Terraform state, shared by all agents

### Other runtimes
- **Colima**: macOS VM-based Docker/k8s (for macOS worker nodes)
- **MicroK8s**: snap-based k8s (alternative to k3s)
- **Podman**: rootless containers without k8s

## Sandbox runtimes

```hcl
enable_gvisor = true    # adds RuntimeClass "gvisor" — use in pod spec: runtimeClassName: gvisor
enable_kata   = false   # adds RuntimeClass "kata"  — heavier, VM-based isolation
```
