#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for the current session (Apple Silicon)
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
fi

brew install --quiet curl wget git jq helm kubectl

echo "Bootstrap complete on $(hostname)"
