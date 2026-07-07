#!/usr/bin/env bash
# Pulse — real-time monitoring dashboard for Docker + Kubernetes (+ Proxmox if available).
# Runs as a Docker container on the host. Agents auto-discover Docker and k8s via socket/kubeconfig.
# Dashboard: http://PULSE_HOSTNAME
# https://github.com/rcourtman/Pulse
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${PULSE_HOSTNAME:=pulse.homelab.local}"
: "${SABLIER_ENABLED:=false}"
: "${SABLIER_SESSION_DURATION:=30m}"

PULSE_PORT=7655

# Detect Docker socket — works for both Linux Docker and macOS Colima
if [[ -S /var/run/docker.sock ]]; then
  DOCKER_SOCK=/var/run/docker.sock
elif [[ -S "$HOME/.colima/default/docker.sock" ]]; then
  DOCKER_SOCK="$HOME/.colima/default/docker.sock"
else
  echo "WARNING: No Docker socket found — Pulse will run without Docker monitoring"
  DOCKER_SOCK=""
fi

# Pull latest release tag
PULSE_TAG=$(curl -fsSL https://api.github.com/repos/rcourtman/Pulse/releases/latest \
  | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
PULSE_TAG="${PULSE_TAG:-6.0.4}"

# Remove old container if present
docker rm -f pulse 2>/dev/null || true

DOCKER_ARGS=(
  run -d
  --name pulse
  --restart unless-stopped
  -p "127.0.0.1:${PULSE_PORT}:${PULSE_PORT}"
)

[[ -n "${DOCKER_SOCK}" ]] && DOCKER_ARGS+=(
  -v "${DOCKER_SOCK}:/var/run/docker.sock:ro"
)

# Mount kubeconfig so Pulse can discover k8s workloads
if [[ -f "${KUBECONFIG}" ]]; then
  DOCKER_ARGS+=(
    -v "${KUBECONFIG}:/root/.kube/config:ro"
    -e "KUBECONFIG=/root/.kube/config"
  )
fi

DOCKER_ARGS+=("ghcr.io/rcourtman/pulse:${PULSE_TAG}")

docker "${DOCKER_ARGS[@]}"

echo "Pulse container started on 127.0.0.1:${PULSE_PORT}"

# Expose through Traefik if it's running
if kubectl --kubeconfig "${KUBECONFIG}" get ns traefik &>/dev/null 2>&1; then
  # shellcheck disable=SC2034
  MIDDLEWARE_ANNOTATION=""
  if [[ "${SABLIER_ENABLED}" == "true" ]]; then
    # shellcheck disable=SC2034
    MIDDLEWARE_ANNOTATION='traefik.ingress.kubernetes.io/router.middlewares: "sablier-blocking@kubernetescrd"'
  fi

  kubectl --kubeconfig "${KUBECONFIG}" apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: pulse
  namespace: default
spec:
  type: ExternalName
  externalName: host.k3s.internal
  ports:
    - port: ${PULSE_PORT}
      targetPort: ${PULSE_PORT}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: pulse
  namespace: default
  annotations:
    sablier.enable: "true"
    sablier.group: pulse
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`${PULSE_HOSTNAME}\`)
      kind: Rule
      services:
        - name: pulse
          port: ${PULSE_PORT}
EOF
  echo "Traefik IngressRoute: http://${PULSE_HOSTNAME}"
else
  echo "Traefik not running — direct access via SSH tunnel:"
  echo "  ssh -L ${PULSE_PORT}:localhost:${PULSE_PORT} <user>@<host>"
  echo "  open http://localhost:${PULSE_PORT}"
fi
