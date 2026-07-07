#!/usr/bin/env bash
# Polaris — Kubernetes best-practices validator (dashboard + optional admission webhook).
# Scans all workloads for: missing resource limits, security context, liveness probes etc.
# Dashboard shows a scorecard + per-namespace breakdown.
# https://github.com/FairwindsOps/polaris
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${POLARIS_HOSTNAME:=polaris.homelab.local}"
: "${SABLIER_ENABLED:=false}"
: "${SABLIER_SESSION_DURATION:=30m}"

export KUBECONFIG

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

helm repo add fairwinds-stable https://charts.fairwinds.com/stable 2>/dev/null || true
helm repo update fairwinds-stable

helm upgrade --install polaris fairwinds-stable/polaris \
  --namespace polaris \
  --create-namespace \
  --wait \
  --timeout 3m \
  --set dashboard.enable=true \
  --set dashboard.service.type=ClusterIP \
  --set webhook.enable=false   # set to true to BLOCK non-compliant pods at admission

echo "Polaris dashboard deployed in namespace: polaris"

# Expose through Traefik
kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: polaris
  namespace: polaris
  annotations:
    sablier.enable: "true"
    sablier.group: polaris
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`${POLARIS_HOSTNAME}\`)
      kind: Rule
      services:
        - name: polaris-dashboard
          port: 80
EOF

echo ""
echo "Polaris dashboard: http://${POLARIS_HOSTNAME}"
echo ""
echo "What Polaris checks for each workload:"
echo "  - Resource limits/requests (CPU + memory)"
echo "  - Security context (runAsNonRoot, readOnlyRootFilesystem)"
echo "  - Liveness + readiness probes"
echo "  - Image tag pinning (no :latest)"
echo "  - Pod disruption budgets"
echo ""
echo "To enable the admission webhook (block non-compliant pods):"
echo "  helm upgrade polaris fairwinds-stable/polaris -n polaris --set webhook.enable=true"
