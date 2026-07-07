#!/usr/bin/env bash
# Shared helpers — source this at the top of every script

set -euo pipefail

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}→${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}!${RESET} $*"; }
die()     { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}$*${RESET}\n"; }

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

# prompt_input VAR "Prompt text" [default]
prompt_input() {
  local -n _ref=$1
  local prompt="${2}"
  local default="${3:-}"
  if [[ -n "${default}" ]]; then
    read -r -p "$(echo -e "${CYAN}?${RESET} ${prompt} [${default}]: ")" _ref
    _ref="${_ref:-$default}"
  else
    read -r -p "$(echo -e "${CYAN}?${RESET} ${prompt}: ")" _ref
  fi
}

# prompt_secret VAR "Prompt text"
prompt_secret() {
  local -n _ref=$1
  local prompt="${2}"
  read -r -s -p "$(echo -e "${CYAN}?${RESET} ${prompt}: ")" _ref
  echo  # newline after hidden input
}

# confirm "Question?" → exits 1 if user says no
confirm() {
  local prompt="${1:-Are you sure?}"
  read -r -p "$(echo -e "${YELLOW}?${RESET} ${prompt} [y/N] ")" ans
  [[ "${ans,,}" =~ ^(y|yes)$ ]] || return 1
}

# ---------------------------------------------------------------------------
# Tool checks
# ---------------------------------------------------------------------------

need() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || die "Required tool not found: ${cmd} (run: mise run install)"
  done
}

# ---------------------------------------------------------------------------
# SSH helpers
# ---------------------------------------------------------------------------

# ssh_run HOST PORT USER KEY_PATH CMD...
# Runs CMD on remote host; returns output.
ssh_run() {
  local host="$1" port="$2" user="$3" key="$4"
  shift 4
  ssh -o StrictHostKeyChecking=accept-new \
      -o BatchMode=yes \
      -o ConnectTimeout=10 \
      -p "${port}" \
      -i "${key}" \
      "${user}@${host}" "$@"
}

# ssh_exec HOST PORT USER KEY_PATH — replaces current process with SSH session
ssh_exec() {
  local host="$1" port="$2" user="$3" key="$4"
  exec ssh -o StrictHostKeyChecking=accept-new \
           -o ConnectTimeout=10 \
           -p "${port}" \
           -i "${key}" \
           -t \
           "${user}@${host}"
}

# ---------------------------------------------------------------------------
# OpenTofu helpers
# ---------------------------------------------------------------------------

TF_DIR="${TF_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/environments/homelab}"

tofu_output() {
  local key="$1"
  tofu -chdir="${TF_DIR}" output -raw "${key}" 2>/dev/null || echo ""
}

tofu_output_json() {
  local key="$1"
  tofu -chdir="${TF_DIR}" output -json "${key}" 2>/dev/null || echo "null"
}

# ---------------------------------------------------------------------------
# fzf picker with bash-select fallback
# ---------------------------------------------------------------------------

# pick_from VARNAME item1 item2 ...
pick_from() {
  local -n _result=$1
  shift
  local items=("$@")

  if command -v fzf &>/dev/null && [[ -t 0 ]]; then
    _result=$(printf '%s\n' "${items[@]}" | fzf --height=40% --border --prompt="Select > ")
  else
    echo "Select an option:"
    select opt in "${items[@]}"; do
      [[ -n "${opt}" ]] && _result="${opt}" && break
    done
  fi
  [[ -n "${_result}" ]] || die "Nothing selected."
}
