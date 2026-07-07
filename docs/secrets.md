# Secrets

## SOPS + age

All secrets live in `environments/lab/terraform.tfvars` (git-ignored). The encrypted copy `terraform.tfvars.enc` is committed.

### One-time setup

```bash
mise run secrets-init
# Output: your age public key, patched into .sops.yaml
# Private key: ~/.config/sops/age/keys.txt  (never commit this)
```

Add the private key to GitHub Secrets for CI:
```bash
gh secret set SOPS_AGE_KEY < ~/.config/sops/age/keys.txt
```

### Daily workflow

```bash
# After editing terraform.tfvars:
mise run secrets-encrypt   # → terraform.tfvars.enc (commit this)

# On fresh clone or new machine:
mise run secrets-decrypt   # → terraform.tfvars (from .enc)
```

### Key rotation

1. Generate new keypair: `age-keygen -o /tmp/new-key.txt`
2. Re-encrypt: `SOPS_AGE_KEY=$(cat /tmp/new-key.txt) sops updatekeys environments/lab/terraform.tfvars.enc`
3. Replace `~/.config/sops/age/keys.txt` with the new key
4. Update `gh secret set SOPS_AGE_KEY < /tmp/new-key.txt`
5. Update `.sops.yaml` with new public key

## k3s at-rest encryption

k3s is installed with `--secrets-encryption`. This encrypts all Kubernetes Secret objects in etcd using AES-CBC. The encryption config is at `/var/lib/rancher/k3s/server/crypt.json` on the primary node.

## Tailscale guest isolation

Devices tagged `tag:homelab-guest` can only reach port 9000 (MinIO S3 API) on homelab nodes. They cannot SSH or reach any admin UI. Managed via `tailscale.tf` — the ACL is applied via the Tailscale Terraform provider.

Tag a device as guest in the Tailscale admin panel, or via:
```bash
tailscale up --advertise-tags=tag:homelab-guest
```

See [Access](access.md) for the full host vs guest breakdown.
