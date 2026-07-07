#!/usr/bin/env bash
# Install Colima on a macOS worker and join its Linux VM as a k3s agent
# to an existing k3s server (running in a Colima VM on another Mac or Linux host).
#
# How it works:
#   1. Install Colima + Docker on this Mac
#   2. Start a Colima VM with --network-address (gets a LAN-accessible IP)
#   3. SSH into the Colima VM
#   4. Install k3s agent inside the VM, joining the remote server
set -euo pipefail

: "${K3S_URL:?K3S_URL is required (e.g. https://192.168.1.10:6443)}"
: "${K3S_TOKEN:?K3S_TOKEN is required}"
: "${K3S_RELEASE:=v1.30.5+k3s1}"

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null \
  || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true

brew install --quiet colima docker 2>/dev/null || true

# Start a worker VM (no k8s — just Lima VM with Docker for the agent to use)
if ! colima status 2>/dev/null | grep -q "Running"; then
  colima start --cpu 2 --memory 4 --disk 40 --network-address
fi

# Get the Colima VM's SSH details
COLIMA_SSH_PORT=$(colima ssh-config 2>/dev/null | awk '/Port/{print $2}' | head -1)
COLIMA_SSH_KEY="${HOME}/.colima/ssh_key"
COLIMA_VM_HOST="127.0.0.1"   # Colima SSH is tunnelled via localhost

if [[ -z "${COLIMA_SSH_PORT}" ]]; then
  echo "Could not determine Colima VM SSH port" >&2
  exit 1
fi

# Install k3s agent inside the Colima VM
ssh -p "${COLIMA_SSH_PORT}" \
    -i "${COLIMA_SSH_KEY}" \
    -o StrictHostKeyChecking=accept-new \
    -o BatchMode=yes \
    "${USER}@${COLIMA_VM_HOST}" \
    "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${K3S_RELEASE}' K3S_TOKEN='${K3S_TOKEN}' K3S_URL='${K3S_URL}' sh -s - agent"

echo "Colima worker joined ${K3S_URL}"
