#!/usr/bin/env bash
# Node discovery — reads from `tofu output` then falls back to manual entry.
# Provides: get_nodes(), pick_node()
#
# Node format internally: "label|host|port|user|key_path"

# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# get_nodes — populates global NODES array
# Each element: "label|host|port|user|key_path"
NODES=()

get_nodes() {
  NODES=()
  local primary_host primary_user key_path

  primary_host=$(tofu_output "primary_host" 2>/dev/null || echo "")
  primary_user=$(tofu_output_json "primary_host" 2>/dev/null | jq -r '.user // "ubuntu"' 2>/dev/null || echo "ubuntu")
  key_path="${TF_SSH_KEY:-${HOME}/.ssh/id_rsa}"

  # Try to get the actual SSH user from tfvars (simpler: just read variables)
  local tfvars="${TF_DIR}/terraform.tfvars"
  if [[ -f "${tfvars}" ]]; then
    # Extract primary_user from tfvars
    local u
    u=$(grep -E '^\s*primary_user\s*=' "${tfvars}" 2>/dev/null | awk -F'"' '{print $2}' | head -1)
    [[ -n "${u}" ]] && primary_user="${u}"
    # Extract SSH key path
    local k
    k=$(grep -E '^\s*primary_key_path\s*=' "${tfvars}" 2>/dev/null | awk -F'"' '{print $2}' | head -1)
    [[ -n "${k}" ]] && key_path="${k}"
  fi

  if [[ -n "${primary_host}" ]]; then
    NODES+=("primary (${primary_host})|${primary_host}|22|${primary_user}|${key_path}")

    # Worker nodes from tofu output
    local workers_json
    workers_json=$(tofu_output_json "worker_hosts" 2>/dev/null || echo "{}")
    if [[ "${workers_json}" != "null" && "${workers_json}" != "{}" ]]; then
      while IFS='=' read -r name whost; do
        NODES+=("${name} (${whost})|${whost}|22|${primary_user}|${key_path}")
      done < <(echo "${workers_json}" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
    fi
  fi

  # Always offer manual entry
  NODES+=("-- enter manually --|||")
}

# pick_node — interactive node picker
# Sets globals: NODE_LABEL, NODE_HOST, NODE_PORT, NODE_USER, NODE_KEY
pick_node() {
  get_nodes

  local labels=()
  for n in "${NODES[@]}"; do
    labels+=("$(echo "${n}" | cut -d'|' -f1)")
  done

  local chosen_label
  pick_from chosen_label "${labels[@]}"

  # Find the matching entry
  local entry=""
  for n in "${NODES[@]}"; do
    if [[ "$(echo "${n}" | cut -d'|' -f1)" == "${chosen_label}" ]]; then
      entry="${n}"; break
    fi
  done

  # shellcheck disable=SC2034
  NODE_LABEL=$(echo "${entry}" | cut -d'|' -f1)
  NODE_HOST=$(echo "${entry}"  | cut -d'|' -f2)
  # shellcheck disable=SC2034
  NODE_PORT=$(echo "${entry}"  | cut -d'|' -f3)
  NODE_USER=$(echo "${entry}"  | cut -d'|' -f4)
  NODE_KEY=$(echo "${entry}"   | cut -d'|' -f5)

  # Manual entry fallback
  if [[ "${chosen_label}" == "-- enter manually --" ]]; then
    prompt_input NODE_HOST "SSH host or IP"
    prompt_input NODE_PORT "SSH port" "22"
    prompt_input NODE_USER "SSH username" "ubuntu"
    prompt_input NODE_KEY  "Path to private key" "${HOME}/.ssh/id_rsa"
    # shellcheck disable=SC2034
    NODE_LABEL="${NODE_USER}@${NODE_HOST}"
  fi

  # Expand ~ in key path
  NODE_KEY="${NODE_KEY/#\~/$HOME}"

  [[ -n "${NODE_HOST}" ]] || die "No host specified."
}
