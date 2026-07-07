#!/usr/bin/env bash
# Deploy Dockge — Docker Compose stack manager by louislam (Uptime Kuma author).
# Runs as a Docker container on the host with access to the Docker socket.
# Exposed via a Traefik IngressRoute using host.k3s.internal to reach the host port.
# https://dockge.kuma.pet/
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${DOCKGE_HOST:=dockge.drksci.local}"
: "${STACKS_DIR:=/opt/stacks}"
: "${SABLIER:=true}"
: "${SESSION_DURATION:=30m}"
: "${DOCKGE_PORT:=5001}"

export KUBECONFIG

# ---------------------------------------------------------------------------
# Dockge Docker container (on host, outside k8s)
# ---------------------------------------------------------------------------

if docker inspect dockge &>/dev/null && docker inspect dockge --format '{{.State.Status}}' | grep -q running; then
  echo "Dockge already running — skipping container start"
else
  docker rm -f dockge 2>/dev/null || true

  mkdir -p "${STACKS_DIR}"

  docker run -d \
    --name dockge \
    --restart always \
    -p "127.0.0.1:${DOCKGE_PORT}:5001" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${STACKS_DIR}:/opt/stacks" \
    -v dockge-data:/app/data \
    -e DOCKGE_STACKS_DIR=/opt/stacks \
    louislam/dockge:1

  echo "Dockge container started on 127.0.0.1:${DOCKGE_PORT}"
fi

# ---------------------------------------------------------------------------
# Wait for k8s API before creating resources
# ---------------------------------------------------------------------------
timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

# ---------------------------------------------------------------------------
# Traefik route: host → k8s ExternalName service → Dockge on host
# In k3s the node is reachable from pods via host.k3s.internal
# ---------------------------------------------------------------------------
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: dockge
---
# ExternalName service pointing to the host (where Dockge runs)
apiVersion: v1
kind: Service
metadata:
  name: dockge
  namespace: dockge
spec:
  type: ExternalName
  externalName: host.k3s.internal
  ports:
    - name: http
      port: ${DOCKGE_PORT}
      targetPort: ${DOCKGE_PORT}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: dockge
  namespace: dockge
  annotations:
    # Sablier can't manage a host Docker container directly via k8s annotations,
    # but the container has restart=always so it's always up.
    # Sablier middleware skipped for Dockge (host service, not a k8s Deployment).
spec:
  entryPoints: [web]
  routes:
    - match: Host(\`${DOCKGE_HOST}\`)
      kind: Rule
      services:
        - name: dockge
          port: ${DOCKGE_PORT}
          namespace: dockge
EOF

echo ""
echo "Dockge deployed at http://${DOCKGE_HOST}"
echo "  Stacks directory: ${STACKS_DIR}"
echo "  On first open: create an admin account in the UI."
echo "  Add '$(kubectl get svc -n traefik traefik -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "<traefik-ip>") ${DOCKGE_HOST}' to /etc/hosts"
