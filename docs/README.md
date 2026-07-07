# tf-drksci-lab — documentation

| Document | Description |
|---|---|
| [Architecture](architecture.md) | Topology, network layers, module dependency order |
| [Getting Started](getting-started.md) | First deploy walkthrough |
| [Secrets](secrets.md) | SOPS+age encryption, k3s at-rest, Tailscale guest isolation |
| [DNS](dns.md) | LAN-wide `*.drksci.local` resolution via dnsmasq |
| [Access](access.md) | kubectl, SSH, pod shell, tailnet service exposure |
| [CI/CD](ci-cd.md) | GitHub Actions workflow, path filters, self-hosted runner |
| [Testing](testing.md) | Terratest, pytest+testcontainers, e2e test layers |
| [Multi-node](multi-node.md) | Adding worker nodes, Longhorn HA |
| **Modules** | |
| [ArgoCD](modules/argocd.md) | GitOps continuous delivery |
| [Backup](modules/backup.md) | Velero + rclone + PVC retention detector |
| [Dashboard](modules/dashboard.md) | Kite + Dockge |
| [DNS module](modules/dns.md) | dnsmasq Compose stack |
| [Exposure](modules/exposure.md) | Cloudflare Tunnel + Tailscale operator |
| [Observability](modules/observability.md) | Pulse + Polaris |
| [Registry](modules/registry.md) | Docker registry |
| [Runtime](modules/runtime.md) | k3s, Colima, MicroK8s, Podman |
| [Storage](modules/storage.md) | Longhorn + MinIO |
| **Reference** | |
| [Mise tasks](reference/mise-tasks.md) | All `mise run <task>` commands |
