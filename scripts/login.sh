#!/usr/bin/env bash
# mise run login
# Interactive node picker → replaces current process with SSH session (exec ssh).
# The terminal is fully handed over — Ctrl+D / exit to return.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/nodes.sh"

header "Node Login"

pick_node

info "Connecting to ${NODE_LABEL} as ${NODE_USER}…"
echo ""

# Validate key exists; fall back to password auth if not
SSH_OPTS=(
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=15
  -p "${NODE_PORT}"
  -t   # force pseudo-terminal (needed for interactive shell)
)

if [[ -f "${NODE_KEY}" ]]; then
  SSH_OPTS+=(-i "${NODE_KEY}")
else
  warn "Key not found at ${NODE_KEY} — falling back to password auth"
  SSH_OPTS+=(-o PasswordAuthentication=yes -o PubkeyAuthentication=no)
fi

# exec replaces this script's process — terminal is fully handed over
exec ssh "${SSH_OPTS[@]}" "${NODE_USER}@${NODE_HOST}"
