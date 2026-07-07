# Multi-node setup

## Adding a worker node

In `environments/lab/terraform.tfvars`:

```hcl
worker_nodes = {
  "imac-2" = {
    host             = "192.168.1.11"
    user             = "blake"
    port             = 22
    private_key_path = "~/.ssh/id_rsa"
    os               = "linux"
  }
}
```

Run `mise run deploy`. Terraform will:
1. Bootstrap the worker (curl, git, docker, mise)
2. Install k3s agent: `K3S_URL=https://192.168.1.10:6443 K3S_TOKEN=<shared-token>`
3. Worker joins the cluster automatically

Verify:
```bash
kubectl get nodes
# NAME           STATUS   ROLES                  AGE
# home-imac-01   Ready    control-plane,master   1d
# imac-2         Ready    <none>                 1m
```

## Longhorn with multiple nodes

With 2+ nodes, set replica count to 2 or 3 for HA volumes:

```hcl
longhorn_replica_count = 2
```

Longhorn automatically spreads replicas across available nodes. Single-node deployments use `replica_count = 1` (no redundancy).

## k3s token

The k3s join token is generated as a `random_password` resource and stored in Terraform state. All agents share the same token. The token is passed as `K3S_TOKEN` to both server and agent install scripts.
