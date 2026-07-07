#!/usr/bin/env bash
# mise run user-create
# Creates a system user on a selected cluster node, then optionally logs in as that user.
#
# Flow:
#   1. Pick target node (fzf / select)
#   2. Enter new username
#   3. Choose auth: SSH key | password | both
#   4. Optionally grant sudo
#   5. Create user on remote host
#   6. Optionally exec ssh as the new user (terminal takeover)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/nodes.sh"

header "Create User on Cluster Node"

# ---------------------------------------------------------------------------
# 1. Pick node
# ---------------------------------------------------------------------------
pick_node
info "Target: ${NODE_LABEL}"
echo ""

# ---------------------------------------------------------------------------
# 2. New username
# ---------------------------------------------------------------------------
prompt_input NEW_USER "New username"
[[ "${NEW_USER}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
  || die "Invalid username '${NEW_USER}' — use lowercase letters, digits, _ or -"

# ---------------------------------------------------------------------------
# 3. Auth method
# ---------------------------------------------------------------------------
AUTH_METHOD=""
pick_from AUTH_METHOD "SSH public key" "Password" "Both (key + password)" "No auth (key added later)"

NEW_PUBKEY=""
NEW_PASSWORD=""

case "${AUTH_METHOD}" in
  "SSH public key" | "Both (key + password)")
    echo ""
    info "Paste the public key for ${NEW_USER} (one line, e.g. ssh-ed25519 AAAA…):"
    echo -n "> "
    read -r NEW_PUBKEY
    [[ "${NEW_PUBKEY}" =~ ^(ssh-|ecdsa-) ]] \
      || die "Doesn't look like a valid public key."
    ;;
esac

case "${AUTH_METHOD}" in
  "Password" | "Both (key + password)")
    echo ""
    prompt_secret NEW_PASSWORD "Password for ${NEW_USER}"
    PW_CONFIRM=""
    prompt_secret PW_CONFIRM  "Confirm password"
    [[ "${NEW_PASSWORD}" == "${PW_CONFIRM}" ]] || die "Passwords do not match."
    ;;
esac

# ---------------------------------------------------------------------------
# 4. Sudo
# ---------------------------------------------------------------------------
GRANT_SUDO="no"
echo ""
confirm "Grant sudo access to ${NEW_USER}?" && GRANT_SUDO="yes" || true

# ---------------------------------------------------------------------------
# 5. Summary + confirmation
# ---------------------------------------------------------------------------
echo ""
echo -e "  ${BOLD}Node:${RESET}     ${NODE_LABEL}"
echo -e "  ${BOLD}Username:${RESET} ${NEW_USER}"
echo -e "  ${BOLD}Auth:${RESET}     ${AUTH_METHOD}"
echo -e "  ${BOLD}Sudo:${RESET}     ${GRANT_SUDO}"
echo ""
confirm "Create this user?" || { warn "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
# 6. Remote execution — build the command sequence
# ---------------------------------------------------------------------------

REMOTE_CMDS=()

# Create user with a home directory
REMOTE_CMDS+=("sudo useradd -m -s /bin/bash '${NEW_USER}' 2>/dev/null || true")

# Set password
if [[ -n "${NEW_PASSWORD}" ]]; then
  # Use printf to avoid echo leaving password in process list
  REMOTE_CMDS+=("printf '%s:%s\n' '${NEW_USER}' '${NEW_PASSWORD}' | sudo chpasswd")
fi

# Authorised key
if [[ -n "${NEW_PUBKEY}" ]]; then
  REMOTE_CMDS+=(
    "sudo mkdir -p /home/${NEW_USER}/.ssh"
    "printf '%s\n' '${NEW_PUBKEY}' | sudo tee /home/${NEW_USER}/.ssh/authorized_keys > /dev/null"
    "sudo chmod 700 /home/${NEW_USER}/.ssh"
    "sudo chmod 600 /home/${NEW_USER}/.ssh/authorized_keys"
    "sudo chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/.ssh"
  )
fi

# Sudo
if [[ "${GRANT_SUDO}" == "yes" ]]; then
  REMOTE_CMDS+=("sudo usermod -aG sudo '${NEW_USER}' 2>/dev/null || sudo usermod -aG wheel '${NEW_USER}'")
fi

REMOTE_CMDS+=("echo 'User ${NEW_USER} ready on '$(hostname)")

# Run all commands on remote
info "Creating user on ${NODE_HOST}…"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -p "${NODE_PORT}")
[[ -f "${NODE_KEY}" ]] && SSH_OPTS+=(-i "${NODE_KEY}")

for cmd in "${REMOTE_CMDS[@]}"; do
  ssh "${SSH_OPTS[@]}" "${NODE_USER}@${NODE_HOST}" "${cmd}"
done

success "User '${NEW_USER}' created on ${NODE_LABEL}."

# ---------------------------------------------------------------------------
# 7. Optional: log in immediately as the new user
# ---------------------------------------------------------------------------
echo ""
if confirm "Log in as ${NEW_USER}@${NODE_HOST} now?"; then
  LOGIN_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -p "${NODE_PORT}" -t)

  if [[ -n "${NEW_PUBKEY}" ]]; then
    # Key auth: user needs to provide their matching private key
    prompt_input PRIV_KEY "Path to matching private key for ${NEW_USER}" "${HOME}/.ssh/id_ed25519"
    PRIV_KEY="${PRIV_KEY/#\~/$HOME}"
    [[ -f "${PRIV_KEY}" ]] || die "Private key not found: ${PRIV_KEY}"
    LOGIN_OPTS+=(-i "${PRIV_KEY}")
  else
    LOGIN_OPTS+=(-o PasswordAuthentication=yes -o PubkeyAuthentication=no)
  fi

  info "Handing over terminal to ${NEW_USER}@${NODE_HOST}…"
  exec ssh "${LOGIN_OPTS[@]}" "${NEW_USER}@${NODE_HOST}"
fi
