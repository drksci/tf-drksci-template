#!/usr/bin/env bash
set -euo pipefail

: "${MICROK8S_CHANNEL:=1.30/stable}"

if command -v microk8s &>/dev/null && microk8s status --wait-ready --timeout 5 2>/dev/null; then
  echo "MicroK8s already running — skipping"
  exit 0
fi

if ! command -v snap &>/dev/null; then
  apt-get update -qq && apt-get install -y -qq snapd
fi

snap install microk8s --classic --channel="${MICROK8S_CHANNEL}"
microk8s status --wait-ready --timeout 120

# Add current user to microk8s group
usermod -aG microk8s "${SUDO_USER:-$USER}" 2>/dev/null || true

# Enable essential addons (exclude ingress — Traefik will handle that)
microk8s enable dns storage helm3 metrics-server

# Alias kubectl / helm for convenience
snap alias microk8s.kubectl kubectl 2>/dev/null || true
snap alias microk8s.helm helm 2>/dev/null || true

# Write kubeconfig to standard location for scripts that need it
mkdir -p /root/.kube
microk8s config > /root/.kube/config
chmod 600 /root/.kube/config

mkdir -p /home/"${SUDO_USER:-$USER}"/.kube
microk8s config > /home/"${SUDO_USER:-$USER}"/.kube/config
chown -R "${SUDO_USER:-$USER}" /home/"${SUDO_USER:-$USER}"/.kube 2>/dev/null || true

echo "MicroK8s ready (channel: ${MICROK8S_CHANNEL})"
