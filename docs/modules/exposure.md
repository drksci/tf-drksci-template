# Exposure

Wires services to the outside world: Cloudflare Tunnel (public internet) and Tailscale operator (tailnet).

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `cloudflare_api_token` | string | `""` | CF API token — disables CF if empty |
| `cloudflare_account_id` | string | `""` | Cloudflare account ID |
| `cloudflare_zone_id` | string | `""` | Cloudflare zone ID |
| `cloudflare_domain` | string | `""` | Public domain (e.g. `drksci.com`) |
| `tailscale_auth_key` | string | `""` | Tailscale auth key (reusable+ephemeral) |
| `tailscale_api_key` | string | `""` | Tailscale API key for ACL management |
| `tailscale_tailnet` | string | `""` | Tailnet name (from Tailscale admin) |

## What it deploys

### Cloudflare Tunnel (when `cloudflare_api_token` set)
- `cloudflared` Deployment (2 replicas) in `cloudflare` namespace
- Traefik IngressRoutes for each `exposure = "public"` service
- Cloudflare DNS CNAME records (via `cloudflare.tf`)

### Tailscale operator (when `tailscale_auth_key` set)
- `tailscale-operator` Helm chart in `tailscale` namespace
- `apiServerProxyConfig.mode=auth` — exposes k8s API on tailnet
- Kubernetes Ingress resources for each `exposure = "tailnet"` service

## Service exposure levels

Set per-service in `terraform.tfvars`:
```hcl
argocd_exposure  = "tailnet"   # internal | tailnet | public
minio_console_exposure = "tailnet"
longhorn_exposure = "tailnet"
```

## Tailscale ACL

Guest/host isolation is managed in `tailscale.tf`:
- `tag:homelab-host` — full access + SSH
- `tag:homelab-guest` — MinIO S3 port 9000 only

See [Access](../access.md) and [Secrets](../secrets.md).
