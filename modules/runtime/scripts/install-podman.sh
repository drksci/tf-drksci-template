#!/usr/bin/env bash
# Installs Podman for rootless container work AND k3s (containerd) for Kubernetes.
# Both coexist: Podman owns /run/podman/podman.sock; k3s owns its own containerd.
set -euo pipefail

: "${K3S_RELEASE:=v1.30.5+k3s1}"
: "${K3S_TOKEN:?K3S_TOKEN is required}"

. /etc/os-release 2>/dev/null || true
ID="${ID:-ubuntu}"

# --- Podman ---
if ! command -v podman &>/dev/null; then
  case "$ID" in
    ubuntu|debian)
      apt-get update -qq
      apt-get install -y -qq podman podman-docker
      ;;
    fedora)
      dnf install -y podman
      ;;
    rhel|centos|rocky|almalinux)
      dnf install -y podman
      ;;
    *)
      echo "Install podman manually for: $ID" >&2; exit 1 ;;
  esac
fi

# Expose system-wide Podman socket (for Dagger/Docuum compatibility)
systemctl enable --now podman.socket 2>/dev/null || true

# --- k3s server (uses its own bundled containerd) ---
if systemctl is-active --quiet k3s 2>/dev/null; then
  echo "k3s already running — skipping"
  exit 0
fi

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_RELEASE}" \
  K3S_TOKEN="${K3S_TOKEN}" \
  sh -s - server \
    --write-kubeconfig-mode 0644 \
    --disable traefik \
    --disable servicelb

timeout 180 bash -c \
  'until /usr/local/bin/kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready"; do sleep 3; done'

echo "Podman + k3s ready"
