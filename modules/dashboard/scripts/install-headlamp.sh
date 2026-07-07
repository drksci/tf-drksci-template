#!/usr/bin/env bash
# Deploy Headlamp — lightweight, extensible Kubernetes dashboard.
# Runs inside k8s (Helm), exposed via Traefik IngressRoute.
# Optionally scaled to zero by Sablier when idle.
# https://headlamp.dev/
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${HEADLAMP_HOST:=headlamp.homelab.local}"
: "${SABLIER:=true}"
: "${SESSION_DURATION:=30m}"

export KUBECONFIG

# ---------------------------------------------------------------------------
# Helm install
# ---------------------------------------------------------------------------
if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

helm repo add headlamp https://headlamp-k8s.github.io/headlamp/ 2>/dev/null || true
helm repo update headlamp

helm upgrade --install headlamp headlamp/headlamp \
  --namespace headlamp \
  --create-namespace \
  --wait \
  --timeout 3m \
  --set ingress.enabled=false \
  --set replicaCount=1 \
  --set persistentVolumeClaim.enabled=true \
  --set persistentVolumeClaim.size="1Gi"

# ---------------------------------------------------------------------------
# RBAC: cluster-admin ServiceAccount token for the dashboard
# ---------------------------------------------------------------------------
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: headlamp-admin
  namespace: headlamp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: headlamp-admin
    namespace: headlamp
---
# Static long-lived token (k8s 1.24+ requires explicit Secret for static tokens)
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-admin-token
  namespace: headlamp
  annotations:
    kubernetes.io/service-account.name: headlamp-admin
type: kubernetes.io/service-account-token
EOF

# ---------------------------------------------------------------------------
# Traefik IngressRoute (with optional Sablier middleware)
# ---------------------------------------------------------------------------
MIDDLEWARES=""
if [[ "${SABLIER}" == "true" ]]; then
  # Annotate the Headlamp deployment for Sablier discovery
  kubectl annotate deployment headlamp \
    -n headlamp \
    sablier.enable=true \
    --overwrite 2>/dev/null || true

  MIDDLEWARES=$(cat <<'YAML'
      middlewares:
        - name: sablier-blocking
          namespace: sablier
YAML
)
fi

kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: headlamp
  namespace: headlamp
spec:
  entryPoints: [web]
  routes:
    - match: Host(\`${HEADLAMP_HOST}\`)
      kind: Rule
      services:
        - name: headlamp
          port: 80
          namespace: headlamp
${MIDDLEWARES}
EOF

# ---------------------------------------------------------------------------
# Print login token
# ---------------------------------------------------------------------------
TOKEN=$(kubectl get secret headlamp-admin-token -n headlamp \
  -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

echo ""
echo "Headlamp deployed at http://${HEADLAMP_HOST}"
if [[ -n "${TOKEN}" ]]; then
  echo ""
  echo "  Login token (save this):"
  echo "  ${TOKEN}"
  echo ""
  echo "  Or retrieve later: kubectl get secret headlamp-admin-token -n headlamp -o jsonpath='{.data.token}' | base64 -d"
fi
echo ""
echo "  Add '$(kubectl get svc -n traefik traefik -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "<traefik-ip>") ${HEADLAMP_HOST}' to /etc/hosts"
