#!/usr/bin/env bash
# Install Docuum (https://github.com/stepchowfun/docuum) — LRU Docker image pruner
set -euo pipefail

: "${THRESHOLD:=7 days}"
: "${DOCKER_SOCKET:=/var/run/docker.sock}"

INSTALL_DIR=/usr/local/bin
DOCUUM_BIN="${INSTALL_DIR}/docuum"
RELEASES_API="https://api.github.com/repos/stepchowfun/docuum/releases/latest"

# Detect arch / OS
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$ARCH" in
  x86_64)  ARCH_TAG="x86_64" ;;
  aarch64|arm64) ARCH_TAG="aarch64" ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

if [[ "$OS" == "darwin" ]]; then
  TARGET="${ARCH_TAG}-apple-darwin"
else
  TARGET="${ARCH_TAG}-unknown-linux-musl"
fi

# Download binary if absent or outdated
if ! command -v docuum &>/dev/null; then
  DOWNLOAD_URL=$(curl -fsSL "${RELEASES_API}" \
    | grep "browser_download_url" \
    | grep "${TARGET}" \
    | head -1 \
    | awk -F'"' '{print $4}')

  [[ -z "${DOWNLOAD_URL}" ]] && { echo "Could not find Docuum release for ${TARGET}" >&2; exit 1; }

  curl -fsSL "${DOWNLOAD_URL}" -o "${DOCUUM_BIN}"
  chmod +x "${DOCUUM_BIN}"
fi

if [[ "$OS" == "darwin" ]]; then
  # macOS: launchd plist
  PLIST=/Library/LaunchDaemons/io.docuum.plist
  cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>       <string>io.docuum</string>
  <key>ProgramArguments</key>
  <array>
    <string>${DOCUUM_BIN}</string>
    <string>--threshold</string>
    <string>${THRESHOLD}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>DOCKER_HOST</key>
    <string>unix://${DOCKER_SOCKET}</string>
  </dict>
  <key>RunAtLoad</key>   <true/>
  <key>KeepAlive</key>   <true/>
  <key>StandardOutPath</key>  <string>/var/log/docuum.log</string>
  <key>StandardErrorPath</key> <string>/var/log/docuum.log</string>
</dict>
</plist>
EOF
  launchctl unload "${PLIST}" 2>/dev/null || true
  launchctl load "${PLIST}"
else
  # Linux: systemd unit
  cat > /etc/systemd/system/docuum.service <<EOF
[Unit]
Description=Docuum — LRU Docker image pruner
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
Environment=DOCKER_HOST=unix://${DOCKER_SOCKET}
ExecStart=${DOCUUM_BIN} --threshold "${THRESHOLD}"

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable docuum --now
fi

echo "Docuum installed (threshold: ${THRESHOLD})"
