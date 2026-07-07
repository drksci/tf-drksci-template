# Architecture

## Topology

```
MacBook Air (home-mba-01)
  └── OpenTofu SSH provisioner
        └── iMac (home-imac-01) — primary node
              ├── Colima VM (Linux)
              │     └── k3s server
              │           ├── Traefik (ingress)
              │           ├── ArgoCD
              │           ├── Longhorn (block storage)
              │           ├── Registry
              │           └── ... (all k8s modules)
              └── Docker (host)
                    ├── MinIO (S3 storage)
                    ├── dnsmasq (LAN DNS)
                    └── Dockge (Compose manager)

Optional: iMac-2 / Intel bare metal (worker node)
  └── k3s agent → joins via https://home-imac-01:6443
```

## Network layers

| Layer | Mechanism | Example URL | Requires |
|---|---|---|---|
| Internal | `/etc/hosts` or dnsmasq | `argocd.drksci.local` | LAN + router DNS config |
| Tailnet | Tailscale operator | `argocd.<tailnet>.ts.net` | Tailscale account |
| Public | Cloudflare Tunnel | `argocd.drksci.com` | CF API token + domain |

## Module deployment order

```
bootstrap → runtime (k3s server) → [k3s agents] → sablier → traefik
         → dagger → docuum → sandbox (gVisor/Kata)
         → registry → dashboard → argocd → homepage
         → storage (longhorn → minio) → observability → backup
         → exposure (cloudflared + tailscale-operator) → dns
         → github-runner → botkube
```

## Data flow

```
terraform apply
  └── null_resource (SSH)
        ├── file provisioner  → copies install script to /tmp/
        └── remote-exec       → sudo ./install-*.sh (env vars injected)
              └── script applies k8s manifests / helm charts / docker compose
```

All secrets are injected as environment variables at provisioner time. Nothing is stored on disk unencrypted beyond what k3s etcd holds (encrypted via `--secrets-encryption`).
