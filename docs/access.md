# Access

## kubectl

### Key-based (standard)

```bash
mise run kubeconfig   # fetches from iMac via SSH, writes .kube/homelab.yaml
kubectl get nodes
```

### Tailscale (no SSH key needed)

Requires the Tailscale operator deployed with `apiServerProxyConfig.mode=auth`.

```bash
mise run kubeconfig-tailscale
kubectl get nodes   # authenticates via your Tailscale identity
```

## SSH to nodes

With Tailscale SSH enabled on nodes (`tailscale up --ssh`):
```bash
tailscale ssh blake@home-imac-01
```

No SSH key management. Access is gated by your Tailscale account and ACL tags.

## Pod shell

```bash
mise run shell
# fzf picker: namespace → pod → container
# Falls back to sh if bash is absent
```

## k9s

```bash
mise run k9s   # launches k9s against the homelab kubeconfig
```

## Expose a service on the tailnet

Patches any k8s Service to appear on your tailnet via the Tailscale operator:

```bash
SVC=myapp NS=mynamespace mise run expose
# → myapp will appear as myapp.<tailnet>.ts.net
```

## Tailscale ACL: host vs guest

| Tag | Access |
|---|---|
| `tag:homelab-host` | Full access to all services + SSH to nodes |
| `tag:homelab-guest` | MinIO S3 API (port 9000) only, no SSH |

Tag a device in the Tailscale admin panel. ACL rules are managed in `tailscale.tf` and applied via `terraform apply`.
