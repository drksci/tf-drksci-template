#!/usr/bin/env bash
# One-time setup: generate an age keypair and wire it into .sops.yaml.
# The private key stays LOCAL (never committed). Add it to GitHub Secrets
# as SOPS_AGE_KEY so CI can decrypt at runtime.
set -euo pipefail

KEYS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sops/age"
KEYS_FILE="$KEYS_DIR/keys.txt"
SOPS_YAML="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/.sops.yaml"

if [[ -f "$KEYS_FILE" ]]; then
  echo "Age keypair already exists at $KEYS_FILE"
  PUBLIC_KEY=$(grep "^# public key:" "$KEYS_FILE" | awk '{print $NF}')
else
  mkdir -p "$KEYS_DIR"
  age-keygen -o "$KEYS_FILE"
  PUBLIC_KEY=$(grep "^# public key:" "$KEYS_FILE" | awk '{print $NF}')
  echo "Generated new age keypair → $KEYS_FILE"
fi

echo ""
echo "Public key: $PUBLIC_KEY"

# Patch .sops.yaml with the real public key
sed -i '' "s|age1REPLACE_WITH_YOUR_PUBLIC_KEY|${PUBLIC_KEY}|" "$SOPS_YAML"
echo "Patched .sops.yaml with public key."

echo ""
echo "Next steps:"
echo "  1. Add private key to GitHub Secrets as SOPS_AGE_KEY:"
echo "       gh secret set SOPS_AGE_KEY < $KEYS_FILE"
echo "  2. Encrypt your tfvars:  mise run secrets-encrypt"
echo "  3. Commit .sops.yaml (public key only — already tracked)"
echo "  4. NEVER commit $KEYS_FILE"
