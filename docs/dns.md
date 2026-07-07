# DNS

## How it works

The `dns` module deploys a **dnsmasq** Docker Compose stack (Dockge-managed) on the primary node. It resolves all `*.drksci.local` hostnames to the Traefik LoadBalancer IP.

Enabled automatically when `traefik_lb_ip` is set in `terraform.tfvars`.

## Router setup

After first deploy, set your router's DHCP DNS server to the iMac's LAN IP (e.g. `192.168.1.10`). All devices on the network then resolve `*.drksci.local` automatically — no `/etc/hosts` needed on any device.

Router config location varies by model. Look for: DHCP settings → DNS server → set to iMac IP.

## Testing

From any LAN device:
```bash
nslookup argocd.drksci.local 192.168.1.10
dig @192.168.1.10 minio.drksci.local
```

From the iMac itself:
```bash
docker logs dnsmasq 2>&1 | tail -20
```

## /etc/hosts fallback

Before dnsmasq is active (or from a non-LAN network), add to `/etc/hosts`:
```
192.168.1.100  home.drksci.local argocd.drksci.local kite.drksci.local
192.168.1.100  dockge.drksci.local minio.drksci.local s3.drksci.local
192.168.1.100  longhorn.drksci.local pulse.drksci.local polaris.drksci.local
192.168.1.100  registry.drksci.local
```

Replace `192.168.1.100` with your actual Traefik LB IP (`mise run output | grep traefik`).
