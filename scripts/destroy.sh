#!/usr/bin/env bash
# mise run destroy — destroys the homelab stack after double confirmation
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

header "Homelab CI/CD — Destroy"
warn "This will DESTROY the entire homelab stack."

confirm "Are you sure you want to destroy?" || { info "Aborted."; exit 0; }
confirm "Really? This cannot be undone."    || { info "Aborted."; exit 0; }

tofu -chdir="${TF_DIR}" destroy
success "Stack destroyed."
