# ArgoCD

GitOps continuous delivery for Kubernetes. Watches git repos and reconciles cluster state.

ArgoCD is intentionally excluded from Sablier (scale-to-zero) — it must always be running to receive git webhooks.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_argocd` | bool | `true` | Deploy ArgoCD |
| `argocd_hostname` | string | `argocd.drksci.local` | Traefik IngressRoute hostname |
| `argocd_exposure` | string | `internal` | `internal` \| `tailnet` \| `public` |
| `argocd_version` | string | `""` | Helm chart version (empty = latest) |

## What it deploys

- ArgoCD via Helm chart (`argo/argo-cd`)
- Traefik IngressRoute matching `argocd_hostname`
- gRPC route for `argocd` CLI (same host, `Content-Type: application/grpc`)
- Runs in `--insecure` mode (Traefik terminates TLS)

## Initial credentials

```bash
mise run argocd-password   # prints initial admin password
```

Change on first login, then delete the bootstrap secret:
```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```

## CLI

```bash
argocd login argocd.drksci.local --username admin --insecure
argocd app list
```
