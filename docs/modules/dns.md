# DNS module

Deploys a **dnsmasq** Docker Compose stack that resolves `*.drksci.local` → Traefik LB IP for the entire LAN.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `traefik_lb_ip` | string | `""` | Traefik LB IP — module only deploys when set |
| `internal_domain` | string | `drksci.local` | DNS zone to serve |
| `dockge_stacks_dir` | string | `/opt/stacks` | Where to write the Compose stack |
| `dns_port` | number | `53` | Port to bind (53 requires NET_ADMIN cap) |

## When it deploys

Only when `traefik_lb_ip != ""`. Get the IP after first deploy:
```bash
mise run output | grep traefik_lb_ip
# then set it in terraform.tfvars and re-apply
```

## Setup

After deploy, point your router's DHCP DNS server to the iMac's LAN IP. All LAN devices will resolve `*.drksci.local` automatically.

See [DNS guide](../dns.md) for full instructions.
