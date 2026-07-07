#!/usr/bin/env bash
set -euo pipefail

: "${K3S_RELEASE:=v1.30.5+k3s1}"
: "${K3S_TOKEN:?K3S_TOKEN is required}"
: "${CRI:=containerd}"   # containerd | crio

if systemctl is-active --quiet k3s 2>/dev/null; then
  echo "k3s server already running — skipping"
  exit 0
fi

# ---------------------------------------------------------------------------
# CRI-O: install before k3s so k3s can detect the socket
# ---------------------------------------------------------------------------
if [[ "${CRI}" == "crio" ]]; then
  SCRIPT_DIR="$(dirname "$0")"
  K8S_VERSION="${K3S_RELEASE%%+*}"   # strip +k3s1 suffix
  K8S_VERSION="${K8S_VERSION}" bash "${SCRIPT_DIR}/install-crio.sh"
fi

# ---------------------------------------------------------------------------
# k3s install
# ---------------------------------------------------------------------------
K3S_EXEC_ARGS=(
  server
  --write-kubeconfig-mode 0644
  --disable traefik
  --disable servicelb
  --secrets-encryption
)

if [[ "${CRI}" == "crio" ]]; then
  K3S_EXEC_ARGS+=(--container-runtime-endpoint unix:///var/run/crio/crio.sock)
fi

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_RELEASE}" \
  K3S_TOKEN="${K3S_TOKEN}" \
  sh -s - "${K3S_EXEC_ARGS[@]}"

# Wait for node ready
timeout 180 bash -c \
  'until /usr/local/bin/kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready"; do sleep 3; done'

echo "k3s server ready (CRI: ${CRI}) — $(kubectl get nodes --no-headers | wc -l) node(s)"
