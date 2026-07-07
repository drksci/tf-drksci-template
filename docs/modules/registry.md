# Registry

Private Docker registry for storing images built by CI/CD.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_registry` | bool | `true` | Deploy registry |
| `registry_hostname` | string | `registry.drksci.local` | Registry URL |
| `registry_storage_size` | string | `80Gi` | Longhorn PVC size |
| `registry_retention_days` | number | `30` | Days to keep untagged images |
| `registry_exposure` | string | `internal` | `internal` \| `tailnet` \| `public` |

## What it deploys

- Docker registry Helm chart in `registry` namespace
- Longhorn PVC for image storage
- Traefik IngressRoute
- Docuum handles GC of old images (configured by `registry_retention_days`)

## Usage

```bash
# Push an image
docker tag myapp registry.drksci.local/myapp:latest
docker push registry.drksci.local/myapp:latest

# List images
curl http://registry.drksci.local/v2/_catalog

# In a k8s manifest
image: registry.drksci.local/myapp:latest
```

k3s nodes are configured to trust the registry as an insecure registry automatically.
