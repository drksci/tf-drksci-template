#!/usr/bin/env bash
# Install CRI-O as the container runtime interface.
# Called by install-k3s-server.sh when CRI=crio.
# https://cri-o.io/
set -euo pipefail

. /etc/os-release 2>/dev/null || true
ID="${ID:-ubuntu}"
VERSION_ID="${VERSION_ID:-22.04}"

: "${K8S_VERSION:=v1.30}"
CRIO_MINOR=$(echo "${K8S_VERSION}" | grep -oE 'v?[0-9]+\.[0-9]+' | head -1 | tr -d 'v')

if command -v crio &>/dev/null; then
  echo "CRI-O already installed — skipping"
  exit 0
fi

case "$ID" in
  ubuntu|debian)
    apt-get update -qq
    apt-get install -y -qq apt-transport-https ca-certificates curl gpg

    # Kubernetes repo (for versioned packages)
    KUBE_REPO="https://pkgs.k8s.io/addons:/cri-o:/stable:/v${CRIO_MINOR}/deb"
    curl -fsSL "${KUBE_REPO}/Release.key" | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] ${KUBE_REPO}/ /" \
      > /etc/apt/sources.list.d/cri-o.list

    apt-get update -qq
    apt-get install -y -qq cri-o
    ;;

  fedora|rhel|centos|rocky|almalinux)
    KUBE_REPO="https://pkgs.k8s.io/addons:/cri-o:/stable:/v${CRIO_MINOR}/rpm"
    cat > /etc/yum.repos.d/cri-o.repo <<EOF
[cri-o]
name=CRI-O
baseurl=${KUBE_REPO}/
enabled=1
gpgcheck=1
gpgkey=${KUBE_REPO}/repodata/repomd.xml.key
EOF
    dnf install -y cri-o
    ;;

  *)
    echo "Unsupported distro for CRI-O: ${ID}" >&2
    exit 1
    ;;
esac

# Enable and start CRI-O
systemctl enable crio --now
echo "CRI-O ${CRIO_MINOR} installed and running"
