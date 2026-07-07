# Getting started

## Prerequisites

- macOS with `mise` installed (`curl https://mise.run | sh`)
- SSH key at `~/.ssh/id_rsa` (or configure `primary_key_path` in tfvars)
- iMac on the same network, SSH enabled, user with sudo
- Tailscale account (free tier is fine for internal use)
- GitHub account (for `tf-drksci-lab` private repo)

## 1. Clone

```bash
git clone https://github.com/drksci/tf-drksci-lab ~/Projects/tf-drksci-lab
cd ~/Projects/tf-drksci-lab
mise install
```

## 2. Secrets setup (one-time)

```bash
mise run secrets-init          # generates age keypair, patches .sops.yaml
cp environments/lab/terraform.tfvars.example environments/lab/terraform.tfvars
# edit terraform.tfvars — at minimum set:
#   primary_host = "192.168.x.x"   # iMac LAN IP
#   minio_root_password = "..."
mise run secrets-encrypt       # produces terraform.tfvars.enc (commit this)
gh secret set SOPS_AGE_KEY < ~/.config/sops/age/keys.txt
```

On a fresh clone (or CI), decrypt before deploying:
```bash
mise run secrets-decrypt
```

## 3. Deploy

```bash
mise run init     # tofu init (run once after clone)
mise run deploy   # full stack: bootstrap → runtime → all modules
```

First deploy takes ~10–15 minutes (k3s install, Helm charts, image pulls).

## 4. Post-deploy

```bash
# Fetch kubeconfig (SSH key-based)
mise run kubeconfig

# Or via Tailscale (no key needed, after exposure module deploys)
mise run kubeconfig-tailscale

# Verify
kubectl get nodes
kubectl get pods -A
```

### /etc/hosts (until dnsmasq module is active)

The dnsmasq module deploys when `traefik_lb_ip` is set in tfvars. Get the IP:
```bash
mise run output | grep traefik
```

Add to `/etc/hosts` on your MacBook:
```
192.168.1.100  home.drksci.local argocd.drksci.local kite.drksci.local
192.168.1.100  dockge.drksci.local pulse.drksci.local polaris.drksci.local
192.168.1.100  minio.drksci.local s3.drksci.local longhorn.drksci.local
192.168.1.100  registry.drksci.local
```

Once dnsmasq is running, point your router's DHCP DNS to the iMac's LAN IP and remove the hosts entries. See [DNS](dns.md).

## 5. Open services

```bash
mise run dashboard-open   # prints all service URLs
```

Default credentials:
- **ArgoCD**: `admin` / run `mise run argocd-password`
- **MinIO console**: `admin` / `minio_root_password` from tfvars
- **Longhorn**: no auth (tailnet-only by default)
