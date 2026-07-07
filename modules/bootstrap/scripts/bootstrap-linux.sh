#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

. /etc/os-release 2>/dev/null || true
ID="${ID:-ubuntu}"

apt_install() {
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends "$@"
}

dnf_install() {
  dnf install -y "$@"
}

case "$ID" in
  ubuntu|debian|raspbian)
    apt_install curl wget ca-certificates gnupg lsb-release \
      apt-transport-https software-properties-common \
      git jq unzip tar open-iscsi nfs-common

    # Docker (needed for Dagger engine and some runtimes)
    if ! command -v docker &>/dev/null; then
      curl -fsSL https://get.docker.com | sh
      systemctl enable docker --now
      usermod -aG docker "${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}" 2>/dev/null || true
    fi

    # Helm
    if ! command -v helm &>/dev/null; then
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi

    # kubectl (used by sablier/traefik install scripts)
    if ! command -v kubectl &>/dev/null; then
      KVER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
      curl -fsSLo /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KVER}/bin/linux/$(dpkg --print-architecture)/kubectl"
      chmod +x /usr/local/bin/kubectl
    fi
    ;;

  fedora|rhel|centos|rocky|almalinux)
    dnf_install curl wget ca-certificates gnupg git jq unzip tar

    if ! command -v docker &>/dev/null; then
      dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      dnf_install docker-ce docker-ce-cli containerd.io
      systemctl enable docker --now
      usermod -aG docker "${SUDO_USER:-$USER}" 2>/dev/null || true
    fi

    if ! command -v helm &>/dev/null; then
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    ;;

  *)
    echo "Unsupported distro: $ID — install curl, docker, helm, kubectl manually" >&2
    exit 1
    ;;
esac

echo "Bootstrap complete on $(hostname)"
