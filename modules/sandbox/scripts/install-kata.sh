#!/usr/bin/env bash
# Install Kata Containers and register with containerd.
# VM-per-pod hardware isolation via QEMU / cloud-hypervisor.
# Requires KVM: egrep -c '(vmx|svm)' /proc/cpuinfo must be > 0
# https://katacontainers.io/
set -euo pipefail

: "${HYPERVISOR:=qemu}"
: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
export KUBECONFIG

# Check KVM available
if [[ $(egrep -c '(vmx|svm)' /proc/cpuinfo 2>/dev/null) -eq 0 ]]; then
  echo "ERROR: KVM not available — Kata requires hardware virtualisation." >&2
  echo "       Check BIOS settings or use gVisor instead (no KVM required)." >&2
  exit 1
fi

. /etc/os-release 2>/dev/null || true
ID="${ID:-ubuntu}"

case "$ID" in
  ubuntu|debian)
    apt-get update -qq
    apt-get install -y -qq kata-containers-runtime 2>/dev/null || {
      # Fallback: GitHub releases installer
      KATA_VERSION=$(curl -fsSL https://api.github.com/repos/kata-containers/kata-containers/releases/latest | jq -r '.tag_name')
      ARCH=$(uname -m)
      curl -fsSL \
        "https://github.com/kata-containers/kata-containers/releases/download/${KATA_VERSION}/kata-static-${KATA_VERSION}-${ARCH}.tar.xz" \
        | tar -xJ -C /
    }
    ;;
  fedora|rhel|centos|rocky|almalinux)
    dnf install -y kata-containers 2>/dev/null || {
      echo "Install kata-containers manually for ${ID}" >&2; exit 1
    }
    ;;
  *)
    echo "Unsupported distro: ${ID}" >&2; exit 1 ;;
esac

KATA_RUNTIME="/usr/bin/containerd-shim-kata-v2"
[[ -x "${KATA_RUNTIME}" ]] || KATA_RUNTIME="/opt/kata/bin/containerd-shim-kata-v2"

# Register with containerd
CONTAINERD_CONFIG=/etc/containerd/config.toml
mkdir -p /etc/containerd
[[ -f "${CONTAINERD_CONFIG}" ]] || containerd config default > "${CONTAINERD_CONFIG}"

if ! grep -q '"kata"' "${CONTAINERD_CONFIG}" 2>/dev/null; then
  cat >> "${CONTAINERD_CONFIG}" <<EOF

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
  runtime_type = "io.containerd.kata.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata.options]
    ConfigPath = "/opt/kata/share/defaults/kata-containers/configuration-${HYPERVISOR}.toml"
EOF
  systemctl restart containerd 2>/dev/null || systemctl restart k3s 2>/dev/null || true
fi

kubectl apply -f - <<'EOF'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
overhead:
  podFixed:
    memory: "160Mi"
    cpu: "250m"
EOF

echo "Kata Containers installed (hypervisor: ${HYPERVISOR})"
echo "  Use in pod spec: runtimeClassName: kata"
