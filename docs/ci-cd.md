# CI/CD

## GitHub Actions workflow

`.github/workflows/validate.yml` runs on every push/PR touching `.tf`, `.sh`, `tests/`, or `mise.toml`.

### Jobs

| Job | Trigger | What it does |
|---|---|---|
| `changes` | Always | Detects which paths changed (dorny/paths-filter) |
| `static` | tf or scripts changed | `tofu fmt`, `tofu validate`, `shellcheck` |
| `terratest` | tf files changed | Terratest plan-level Go tests |
| `pytest-smoke` | scripts changed | Fast syntax checks (no Docker) |
| `integration` | `workflow_dispatch` or `test/*` branch | Full k3s deploy to runner, smoke tests |

### SOPS decrypt in CI

The integration job decrypts `terraform.tfvars.enc` if `SOPS_AGE_KEY` is set:
```yaml
- name: Decrypt tfvars
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
  run: |
    if [[ -n "${SOPS_AGE_KEY}" && -f terraform.tfvars.enc ]]; then
      echo "${SOPS_AGE_KEY}" | sops --decrypt terraform.tfvars.enc > terraform.tfvars
    fi
```

If not set, the job falls back to generated test tfvars (deploys to `127.0.0.1`).

### Self-hosted runner

The `enable_github_runner` module deploys `actions-runner-controller` inside the k3s cluster. Self-hosted runner pods have in-cluster `kubectl` access via their service account — no kubeconfig distribution needed.

For real deploys triggered from CI, use the self-hosted runner so it already has tailnet access.

## Dagger

The Dagger engine runs as a Docker container on the primary node. Connect from the MacBook:
```bash
mise run dagger-connect   # opens SSH tunnel → sets DAGGER_RUNNER_HOST
```

Then use `dagger` CLI locally — pipelines execute on the remote engine.
