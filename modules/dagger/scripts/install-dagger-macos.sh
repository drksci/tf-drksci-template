#!/usr/bin/env bash
set -euo pipefail

: "${DAGGER_VERSION:=}"

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null \
  || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true

# Install Dagger CLI
if ! command -v dagger &>/dev/null || [[ -n "${DAGGER_VERSION}" ]]; then
  if [[ -n "${DAGGER_VERSION}" ]]; then
    curl -fsSL https://dl.dagger.io/dagger/install.sh | BIN_DIR=/usr/local/bin DAGGER_VERSION="${DAGGER_VERSION}" sh
  else
    curl -fsSL https://dl.dagger.io/dagger/install.sh | BIN_DIR=/usr/local/bin sh
  fi
fi

DAGGER_BIN=$(command -v dagger)
DAGGER_VER=$("${DAGGER_BIN}" version 2>/dev/null | awk '{print $2}' | head -1)
ENGINE_IMAGE="registry.dagger.io/engine:${DAGGER_VER:-latest}"

# Pull engine image
docker pull "${ENGINE_IMAGE}" 2>/dev/null || true

# Run Dagger engine as persistent Docker container
docker rm -f dagger-engine 2>/dev/null || true
docker run -d \
  --name dagger-engine \
  --restart always \
  --privileged \
  -v dagger-engine-data:/var/lib/dagger \
  "${ENGINE_IMAGE}"

# Write shell profile entry
ZSHENV="${HOME}/.zshenv"
grep -q '_EXPERIMENTAL_DAGGER_RUNNER_HOST' "${ZSHENV}" 2>/dev/null \
  || echo 'export _EXPERIMENTAL_DAGGER_RUNNER_HOST="docker-container://dagger-engine"' >> "${ZSHENV}"

echo "Dagger engine running (${DAGGER_VER:-latest})"
