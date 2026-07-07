#!/usr/bin/env bash
# mise run dagger-status — check Dagger engine on primary node
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

PRIMARY_HOST=$(tofu_output "primary_host")
[[ -n "${PRIMARY_HOST}" ]] || die "primary_host not in tofu output"

TFVARS="${TF_DIR}/terraform.tfvars"
PRIMARY_USER="ubuntu"; PRIMARY_KEY="${HOME}/.ssh/id_rsa"; PRIMARY_PORT="22"
if [[ -f "${TFVARS}" ]]; then
  u=$(grep -E '^\s*primary_user\s*='     "${TFVARS}" 2>/dev/null | awk -F'"' '{print $2}' | head -1)
  k=$(grep -E '^\s*primary_key_path\s*=' "${TFVARS}" 2>/dev/null | awk -F'"' '{print $2}' | head -1)
  [[ -n "${u}" ]] && PRIMARY_USER="${u}"
  [[ -n "${k}" ]] && PRIMARY_KEY="${k/#\~/$HOME}"
fi

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -p "${PRIMARY_PORT}")
[[ -f "${PRIMARY_KEY}" ]] && SSH_OPTS+=(-i "${PRIMARY_KEY}")

header "Dagger Engine Status"
ssh "${SSH_OPTS[@]}" "${PRIMARY_USER}@${PRIMARY_HOST}" \
  "docker inspect dagger-engine --format 'Status: {{.State.Status}}  Uptime: {{.State.StartedAt}}' 2>/dev/null || echo 'dagger-engine container not found'"
