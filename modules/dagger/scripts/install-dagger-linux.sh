#!/usr/bin/env bash
set -euo pipefail

: "${DOCKER_SOCKET:=/var/run/docker.sock}"
: "${DAGGER_VERSION:=}"  # empty = latest

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

# Pull the engine image so first run is fast
ENGINE_IMAGE="registry.dagger.io/engine:${DAGGER_VER:-latest}"
docker pull "${ENGINE_IMAGE}" 2>/dev/null || true

# Run Dagger engine as a persistent container with host restart policy
if docker inspect dagger-engine &>/dev/null; then
  docker rm -f dagger-engine
fi

docker run -d \
  --name dagger-engine \
  --restart always \
  --privileged \
  -v dagger-engine-data:/var/lib/dagger \
  "${ENGINE_IMAGE}"

# Expose runner host globally
PROFILE_D=/etc/profile.d/dagger.sh
cat > "${PROFILE_D}" <<'EOF'
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="docker-container://dagger-engine"
EOF

echo "Dagger engine running (${DAGGER_VER:-latest})"
echo "Set in CI: export _EXPERIMENTAL_DAGGER_RUNNER_HOST=docker-container://dagger-engine"
