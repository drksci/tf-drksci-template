#!/usr/bin/env bash
# Deploys Traefik + Sablier via Helm onto the K8s cluster.
# Traefik acts as the ingress controller; Sablier is a Traefik middleware plugin
# that intercepts requests and wakes dormant workloads on demand.
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${SESSION_DURATION:=10m}"
: "${SABLIER_VERSION:=}"
: "${TRAEFIK_VERSION:=}"
: "${TRAEFIK_LB_IP:=}"

export KUBECONFIG

# Install Helm if absent (bootstrap should have done this, but be safe)
if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Wait for K8s API
timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

# ---------------------------------------------------------------------------
# Traefik — ingress controller with Sablier plugin enabled
# ---------------------------------------------------------------------------
helm repo add traefik https://helm.traefik.io/traefik 2>/dev/null || helm repo update traefik
helm repo update

TRAEFIK_ARGS=(
  upgrade --install traefik traefik/traefik
  --namespace traefik --create-namespace
  --set "ports.web.redirectTo.port=websecure"
  --set "ports.websecure.tls.enabled=true"
  --set "providers.kubernetesIngress.enabled=true"
  --set "providers.kubernetesCRD.enabled=true"
  # Sablier plugin — loaded from Traefik plugin marketplace
  --set "experimental.plugins.sablier.moduleName=github.com/sablierapp/sablier"
  --set "experimental.plugins.sablier.version=v1.8.0"
  --set "logs.general.level=INFO"
)

[[ -n "${TRAEFIK_VERSION}" ]] && TRAEFIK_ARGS+=(--version "${TRAEFIK_VERSION}")

if [[ -n "${TRAEFIK_LB_IP}" ]]; then
  TRAEFIK_ARGS+=(--set "service.spec.loadBalancerIP=${TRAEFIK_LB_IP}")
fi

helm "${TRAEFIK_ARGS[@]}" --wait --timeout 5m

# ---------------------------------------------------------------------------
# Sablier — scale-to-zero controller
# ---------------------------------------------------------------------------
helm repo add sablier https://sablierapp.github.io/sablier 2>/dev/null || helm repo update sablier
helm repo update

SABLIER_ARGS=(
  upgrade --install sablier sablier/sablier
  --namespace sablier --create-namespace
  --set "sablier.storage.file.enabled=true"
  --set "sablier.defaultSessionDuration=${SESSION_DURATION}"
  --set "sablier.blockingDefaultTimeout=${SESSION_DURATION}"
)

[[ -n "${SABLIER_VERSION}" ]] && SABLIER_ARGS+=(--version "${SABLIER_VERSION}")
helm "${SABLIER_ARGS[@]}" --wait --timeout 3m

# ---------------------------------------------------------------------------
# Sablier Traefik middleware CRD
# ---------------------------------------------------------------------------
kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: sablier-blocking
  namespace: sablier
spec:
  plugin:
    sablier:
      sablierUrl: "http://sablier.sablier.svc.cluster.local:10000"
      group: default
      sessionDuration: "${SESSION_DURATION}"
      blocking:
        timeout: "${SESSION_DURATION}"
EOF

echo ""
echo "Traefik + Sablier deployed."
echo "  Traefik LB IP: $(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo 'pending')"
echo "  To opt a Deployment into scale-to-zero:"
echo "    kubectl annotate deployment <name> sablier.enable=true"
echo "    # Then add the 'sablier-blocking@kubernetescrd' middleware to its IngressRoute"
