#!/usr/bin/env bash
# Install gVisor (runsc) and register it as a containerd runtime shim.
# Creates a k8s RuntimeClass so pods can opt in with runtimeClassName: gvisor.
# https://gvisor.dev/docs/user_guide/install/
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
export KUBECONFIG

ARCH=$(uname -m)
[[ "${ARCH}" == "x86_64" ]] || { echo "gVisor requires x86_64; this host is ${ARCH}" >&2; exit 1; }

if command -v runsc &>/dev/null; then
  echo "gVisor (runsc) already installed — skipping binary install"
else
  # Install from official apt repo
  curl -fsSL https://gvisor.dev/archive.key | gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" \
    > /etc/apt/sources.list.d/gvisor.list
  apt-get update -qq
  apt-get install -y -qq runsc
fi

# ---------------------------------------------------------------------------
# Wire gVisor into containerd as a runtime handler
# ---------------------------------------------------------------------------
CONTAINERD_CONFIG=/etc/containerd/config.toml

mkdir -p /etc/containerd
if [[ ! -f "${CONTAINERD_CONFIG}" ]]; then
  containerd config default > "${CONTAINERD_CONFIG}"
fi

# Idempotently append the gVisor runtime section
if ! grep -q '"runsc"' "${CONTAINERD_CONFIG}" 2>/dev/null; then
  cat >> "${CONTAINERD_CONFIG}" <<'EOF'

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
  systemctl restart containerd 2>/dev/null || systemctl restart k3s 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# RuntimeClass — pods use runtimeClassName: gvisor
# ---------------------------------------------------------------------------
kubectl apply -f - <<'EOF'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeClassification:
    tolerations:
      - key: "sandbox.gke.io/runtime"
        operator: "Equal"
        value: "gvisor"
        effect: "NoSchedule"
EOF

echo ""
echo "gVisor installed. Use in a pod:"
echo "  spec:"
echo "    runtimeClassName: gvisor"
echo ""
echo "Verify: kubectl run test --image=alpine --overrides='{\"spec\":{\"runtimeClassName\":\"gvisor\"}}' --command -- uname -r"
