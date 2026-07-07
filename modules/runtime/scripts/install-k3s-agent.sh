#!/usr/bin/env bash
set -euo pipefail

: "${K3S_RELEASE:=v1.30.5+k3s1}"
: "${K3S_TOKEN:?K3S_TOKEN is required}"
: "${K3S_URL:?K3S_URL is required (e.g. https://192.168.1.10:6443)}"

if systemctl is-active --quiet k3s-agent 2>/dev/null; then
  echo "k3s agent already running — skipping"
  exit 0
fi

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_RELEASE}" \
  K3S_TOKEN="${K3S_TOKEN}" \
  K3S_URL="${K3S_URL}" \
  sh -s - agent

echo "k3s agent joined ${K3S_URL}"
