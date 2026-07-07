#!/usr/bin/env bash
set -euo pipefail

: "${CPU:=4}"
: "${MEMORY_GB:=8}"
: "${DISK_GB:=60}"
: "${K8S_VERSION:=v1.30.5}"

if ! command -v brew &>/dev/null; then
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null \
    || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null \
    || { echo "Homebrew required" >&2; exit 1; }
fi

brew install --quiet colima docker docker-compose kubectl helm 2>/dev/null || true

if colima status 2>/dev/null | grep -q "Running"; then
  echo "Colima already running — skipping"
  exit 0
fi

colima start \
  --cpu "${CPU}" \
  --memory "${MEMORY_GB}" \
  --disk "${DISK_GB}" \
  --kubernetes \
  --kubernetes-version "${K8S_VERSION}" \
  --runtime docker \
  --network-address

# Merge kubeconfig
colima kubernetes use --merge --namespace colima 2>/dev/null || true

echo "Colima ready (Docker + K8s ${K8S_VERSION})"
