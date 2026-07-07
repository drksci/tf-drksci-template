#!/usr/bin/env bash
# Join an existing MicroK8s cluster.
# JOIN_URL must be the output of `microk8s add-node` on the control-plane.
set -euo pipefail

: "${MICROK8S_CHANNEL:=1.30/stable}"
: "${JOIN_URL:?JOIN_URL is required (from microk8s add-node on the control-plane)}"

if ! command -v snap &>/dev/null; then
  apt-get update -qq && apt-get install -y -qq snapd
fi

if ! command -v microk8s &>/dev/null; then
  snap install microk8s --classic --channel="${MICROK8S_CHANNEL}"
fi

usermod -aG microk8s "${SUDO_USER:-$USER}" 2>/dev/null || true

microk8s join "${JOIN_URL}"

echo "MicroK8s agent joined cluster"
