#!/usr/bin/env bash
# mise run deploy
# Full stack deployment with pre-flight checks and a clean summary.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

header "Homelab CI/CD — Deploy"

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
need tofu

# Ensure tfvars exist
TFVARS="${TF_DIR}/terraform.tfvars"
if [[ ! -f "${TFVARS}" ]]; then
  warn "terraform.tfvars not found."
  info "Copying example tfvars — fill in your values then re-run deploy."
  cp "${TF_DIR}/terraform.tfvars.example" "${TFVARS}"
  "${EDITOR:-nano}" "${TFVARS}"
fi

# Ensure tofu is initialised
if [[ ! -d "${TF_DIR}/.terraform" ]]; then
  info "Running tofu init…"
  tofu -chdir="${TF_DIR}" init -upgrade
fi

# ---------------------------------------------------------------------------
# Plan + confirm
# ---------------------------------------------------------------------------
info "Planning…"
tofu -chdir="${TF_DIR}" plan -out=/tmp/homelab.tfplan

echo ""
confirm "Apply the above plan?" || { warn "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------
info "Applying…"
tofu -chdir="${TF_DIR}" apply /tmp/homelab.tfplan
rm -f /tmp/homelab.tfplan

# ---------------------------------------------------------------------------
# Post-deploy summary
# ---------------------------------------------------------------------------
header "Deployment complete"

PRIMARY=$(tofu -chdir="${TF_DIR}" output -raw primary_host 2>/dev/null || echo "(unknown)")
KUBECONF_PATH=$(tofu -chdir="${TF_DIR}" output -raw kubeconfig_path 2>/dev/null || echo "")
DAGGER_HOST=$(tofu -chdir="${TF_DIR}" output -raw dagger_runner_host 2>/dev/null || echo "")
REGISTRY=$(tofu -chdir="${TF_DIR}" output -raw registry_url 2>/dev/null || echo "")

echo -e "  Primary node:      ${GREEN}${PRIMARY}${RESET}"
echo -e "  Kubeconfig:        ${GREEN}${KUBECONF_PATH}${RESET}"
echo -e "  Dagger runner:     ${GREEN}${DAGGER_HOST}${RESET}"
[[ -n "${REGISTRY}" ]] && echo -e "  Registry:          ${GREEN}${REGISTRY}${RESET}"

echo ""
info "Fetch kubeconfig locally:  mise run kubeconfig"
info "SSH into primary node:     mise run login"
info "View cluster:              mise run status"
