#!/usr/bin/env bash
# mise run kubeconfig
# Fetches kubeconfig from the primary node and merges it into .kube/homelab.yaml
# so local kubectl / k9s / helm work without SSH-ing in.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

header "Fetch Kubeconfig"

# Read primary node details from tofu output
PRIMARY_HOST=$(tofu_output "primary_host")
KUBECONF_REMOTE=$(tofu_output "kubeconfig_path")

[[ -n "${PRIMARY_HOST}" ]]    || die "primary_host not in tofu output — run: mise run deploy"
[[ -n "${KUBECONF_REMOTE}" ]] || die "kubeconfig_path not in tofu output"

# SSH details from tfvars
TFVARS="${TF_DIR}/terraform.tfvars"
PRIMARY_USER="ubuntu"
PRIMARY_KEY="${HOME}/.ssh/id_rsa"
PRIMARY_PORT="22"

if [[ -f "${TFVARS}" ]]; then
  u=$(grep -E '^\s*primary_user\s*=' "${TFVARS}" 2>/dev/null | awk -F'"' '{print $2}' | head -1)
  k=$(grep -E '^\s*primary_key_path\s*=' "${TFVARS}" 2>/dev/null | awk -F'"' '{print $2}' | head -1)
  p=$(grep -E '^\s*primary_port\s*=' "${TFVARS}" 2>/dev/null | grep -oE '[0-9]+' | head -1)
  [[ -n "${u}" ]] && PRIMARY_USER="${u}"
  [[ -n "${k}" ]] && PRIMARY_KEY="${k/#\~/$HOME}"
  [[ -n "${p}" ]] && PRIMARY_PORT="${p}"
fi

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -p "${PRIMARY_PORT}")
[[ -f "${PRIMARY_KEY}" ]] && SSH_OPTS+=(-i "${PRIMARY_KEY}")

info "Fetching ${KUBECONF_REMOTE} from ${PRIMARY_USER}@${PRIMARY_HOST}…"

LOCAL_KUBECONFIG="${HOMELAB_ROOT}/.kube/homelab.yaml"
mkdir -p "$(dirname "${LOCAL_KUBECONFIG}")"

# Pull kubeconfig; rewrite server address to use actual host (not 127.0.0.1)
ssh "${SSH_OPTS[@]}" "${PRIMARY_USER}@${PRIMARY_HOST}" "sudo cat '${KUBECONF_REMOTE}'" \
  | sed "s|server: https://127.0.0.1:|server: https://${PRIMARY_HOST}:|" \
  | sed "s|server: https://localhost:|server: https://${PRIMARY_HOST}:|" \
  > "${LOCAL_KUBECONFIG}"
chmod 600 "${LOCAL_KUBECONFIG}"

success "Saved to ${LOCAL_KUBECONFIG}"
info "Active (via KUBECONFIG env): kubectl get nodes"

# Test it
echo ""
KUBECONFIG="${LOCAL_KUBECONFIG}" kubectl get nodes 2>/dev/null && success "Cluster reachable" \
  || warn "Cluster not yet reachable — API server may still be starting."
