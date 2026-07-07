#!/usr/bin/env bash
# Deploy dnsmasq as a Dockge-managed Compose stack.
# Resolves *.drksci.local → Traefik LB IP for all LAN devices.
# After deploy: set this machine's LAN IP as the DNS server in your router's DHCP config.
set -euo pipefail

: "${TRAEFIK_IP:?TRAEFIK_IP is required (Traefik LoadBalancer IP)}"
: "${DOMAIN:=drksci.local}"
: "${STACKS_DIR:=/opt/stacks}"
: "${DNS_PORT:=53}"

STACK_DIR="${STACKS_DIR}/dns"
mkdir -p "${STACK_DIR}/config"

# dnsmasq config: wildcard for the internal domain + sane defaults
cat > "${STACK_DIR}/config/dnsmasq.conf" <<EOF
# Resolve all *.${DOMAIN} to the Traefik LoadBalancer
address=/.${DOMAIN}/${TRAEFIK_IP}

# Use system upstream DNS for everything else
no-resolv
server=1.1.1.1
server=8.8.8.8

# Don't read /etc/hosts from inside the container
no-hosts

# Fast negative TTL so renames propagate quickly
neg-ttl=30
local-ttl=60

# Logging
log-queries
log-facility=-
EOF

cat > "${STACK_DIR}/compose.yaml" <<EOF
services:
  dnsmasq:
    image: dockurr/dnsmasq:latest
    container_name: dnsmasq
    ports:
      - "${DNS_PORT}:53/udp"
      - "${DNS_PORT}:53/tcp"
    volumes:
      - ./config/dnsmasq.conf:/etc/dnsmasq.conf:ro
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
EOF

docker compose -f "${STACK_DIR}/compose.yaml" up -d

LAN_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "dnsmasq deployed — resolves *.${DOMAIN} → ${TRAEFIK_IP}"
echo ""
echo "  Next: set your router's DHCP DNS server to: ${LAN_IP}"
echo "  Then all LAN devices resolve *.${DOMAIN} automatically."
echo ""
echo "  Test from another device:"
echo "    nslookup argocd.${DOMAIN} ${LAN_IP}"
