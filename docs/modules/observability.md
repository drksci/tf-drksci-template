# Observability

Real-time monitoring and best-practices auditing.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_observability` | bool | `true` | Deploy observability module |
| `enable_pulse` | bool | `true` | Deploy Pulse monitoring dashboard |
| `pulse_hostname` | string | `pulse.drksci.local` | Pulse URL |
| `enable_polaris` | bool | `true` | Deploy Polaris best-practices audit |
| `polaris_hostname` | string | `polaris.drksci.local` | Polaris URL |
| `pulse_exposure` | string | `internal` | `internal` \| `tailnet` \| `public` |
| `polaris_exposure` | string | `internal` | `internal` \| `tailnet` \| `public` |

## What it deploys

- **Pulse**: Docker container on the host (not in k3s) that monitors Docker containers and Kubernetes workloads in real-time. Exposed via Traefik IngressRoute.
- **Polaris**: Helm chart in k3s that audits deployments for best practices (resource limits, security contexts, etc). Dashboard at `polaris_hostname`.
