#!/usr/bin/env bash
set -euo pipefail

: "${CPU:=4}"
: "${MEMORY_GB:=8}"
: "${K8S_VERSION:=v1.30.5}"

ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
[[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
[[ "$ARCH" == "aarch64" ]] && ARCH="arm64"

if ! command -v minikube &>/dev/null; then
  curl -fsSLo /usr/local/bin/minikube \
    "https://storage.googleapis.com/minikube/releases/latest/minikube-${OS}-${ARCH}"
  chmod +x /usr/local/bin/minikube
fi

if minikube status 2>/dev/null | grep -q "Running"; then
  echo "Minikube already running — skipping"
  exit 0
fi

# Pick driver: prefer docker if available, fall back to qemu/virtualbox
DRIVER="docker"
command -v docker &>/dev/null || DRIVER="qemu2"

minikube start \
  --driver="${DRIVER}" \
  --cpus="${CPU}" \
  --memory="${MEMORY_GB}g" \
  --kubernetes-version="${K8S_VERSION}" \
  --addons=ingress,metrics-server,storage-provisioner

echo "Minikube ready (driver: ${DRIVER})"
