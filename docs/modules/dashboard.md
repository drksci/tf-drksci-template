# Dashboard

Two management UIs: Kite (Kubernetes dashboard) and Dockge (Docker Compose manager).

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_dashboard` | bool | `true` | Deploy dashboard module |
| `enable_kite` | bool | `true` | Deploy Kite k8s UI |
| `enable_dockge` | bool | `true` | Deploy Dockge Compose manager |
| `kite_hostname` | string | `kite.drksci.local` | Kite URL |
| `dockge_hostname` | string | `dockge.drksci.local` | Dockge URL |
| `dockge_stacks_dir` | string | `/opt/stacks` | Host path for Compose stacks |
| `dashboard_session_duration` | string | `30m` | Sablier idle timeout |
| `kite_exposure` | string | `internal` | `internal` \| `tailnet` \| `public` |
| `dockge_exposure` | string | `internal` | `internal` \| `tailnet` \| `public` |

## What it deploys

- **Kite**: lightweight Kubernetes dashboard (no auth — tailnet/internal only)
- **Dockge**: web UI for managing Docker Compose stacks on the host; stacks live at `dockge_stacks_dir`

Dockge manages: MinIO, dnsmasq, and any other Compose stacks you add.
