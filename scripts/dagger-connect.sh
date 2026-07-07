#!/usr/bin/env bash
# mise run dagger-connect
# Opens an SSH tunnel so your local `dagger` CLI talks to the remote engine.
# Sets _EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://localhost:8080 locally.
#
# Usage:
#   mise run dagger-connect          # foreground (Ctrl+C to stop)
#   eval $(mise run dagger-connect --env)  # export env for current shell
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

LOCAL_PORT="${DAGGER_LOCAL_PORT:-8080}"
REMOTE_PORT="${DAGGER_REMOTE_PORT:-8080}"

# Read primary from tofu
PRIMARY_HOST=$(tofu_output "primary_host")
[[ -n "${PRIMARY_HOST}" ]] || die "primary_host not found — run: mise run deploy"

TFVARS="${TF_DIR}/terraform.tfvars"
PRIMARY_USER="ubuntu"
PRIMARY_KEY="${HOME}/.ssh/id_rsa"
if [[ -f "${TFVARS}" ]]; then
  u=$(grep -E '^\s*primary_user\s*=' "${TFVARS}" 2>/dev/null | awk -F'"' '{print $2}' | head -1)
  k=$(grep -E '^\s*primary_key_path\s*=' "${TFVARS}" 2>/dev/null | awk -F'"' '{print $2}' | head -1)
  [[ -n "${u}" ]] && PRIMARY_USER="${u}"
  [[ -n "${k}" ]] && PRIMARY_KEY="${k/#\~/$HOME}"
fi

# --env mode: print export statement for eval
if [[ "${1:-}" == "--env" ]]; then
  echo "export _EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://localhost:${LOCAL_PORT}"
  exit 0
fi

header "Dagger Engine Tunnel"
info "Forwarding localhost:${LOCAL_PORT} → ${PRIMARY_HOST}:${REMOTE_PORT} (dagger engine)"
info "In another terminal: export _EXPERIMENTAL_DAGGER_RUNNER_HOST=tcp://localhost:${LOCAL_PORT}"
info "Press Ctrl+C to close tunnel."
echo ""

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ExitOnForwardFailure=yes -N)
[[ -f "${PRIMARY_KEY}" ]] && SSH_OPTS+=(-i "${PRIMARY_KEY}")

# The Dagger engine exposes its gRPC port inside the container; forward via the host's Docker socket
# For docker-container runner, we tunnel Docker's API port instead and let Dagger use docker-container://
# Simpler: just SSH forward port 8080 if the engine is bound there, otherwise use docker-container.
exec ssh "${SSH_OPTS[@]}" \
  -L "${LOCAL_PORT}:localhost:${REMOTE_PORT}" \
  "${PRIMARY_USER}@${PRIMARY_HOST}"
