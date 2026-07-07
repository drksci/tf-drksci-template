#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for the current session (Apple Silicon or Intel)
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
fi

# Fix common permission issues that cause brew install to fail
BREW_DIRS=(
  /usr/local/lib/pkgconfig
  /usr/local/share/man
  /usr/local/share/man/man1
  /usr/local/share/man/man2
  /usr/local/share/man/man3
  /usr/local/share/man/man4
  /usr/local/share/man/man5
  /usr/local/share/man/man6
  /usr/local/share/man/man7
  /usr/local/share/man/man8
)
for d in "${BREW_DIRS[@]}"; do
  if [[ -d "$d" ]] && [[ ! -w "$d" ]]; then
    sudo chown -R "$(whoami)" "$d" 2>/dev/null || true
  fi
done

# Run brew fully non-interactive: suppresses all prompts (upgrade confirmation,
# tap trust, env hints, CLT warnings). NONINTERACTIVE=1 is the canonical way.
export NONINTERACTIVE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_REQUIRE_TAP_TRUST=1

PKGS=(curl wget git jq helm kubernetes-cli)
brew upgrade --quiet "${PKGS[@]}" 2>/dev/null || true
brew install --quiet "${PKGS[@]}" 2>/dev/null || true

echo "Bootstrap complete on $(hostname)"
