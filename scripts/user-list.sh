#!/usr/bin/env bash
# mise run user-list — list non-system users on a selected node
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/nodes.sh"

header "List Users on Cluster Node"
pick_node

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -p "${NODE_PORT}")
[[ -f "${NODE_KEY}" ]] && SSH_OPTS+=(-i "${NODE_KEY}")

info "Users on ${NODE_LABEL}:"
echo ""

ssh "${SSH_OPTS[@]}" "${NODE_USER}@${NODE_HOST}" \
  "awk -F: '\$3>=1000 && \$1!=\"nobody\" {print \$1, \"(uid=\" \$3 \")\", \"home:\", \$6}' /etc/passwd"
