#!/usr/bin/env bash
# Deploy Kite — multi-cluster Kubernetes dashboard with OAuth, Helm manager,
# Prometheus integration, web terminal, and AI assistant.
# https://github.com/kite-org/kite
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${KITE_HOST:=kite.drksci.local}"
: "${SABLIER:=true}"
: "${SESSION_DURATION:=30m}"
: "${KITE_NAMESPACE:=kube-system}"

export KUBECONFIG

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

# ---------------------------------------------------------------------------
# Helm install
# ---------------------------------------------------------------------------
helm repo add kite https://zxh326.github.io/kite 2>/dev/null || true
helm repo update kite

helm upgrade --install kite kite/kite \
  --namespace "${KITE_NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 3m \
  --set service.type=ClusterIP \
  --set ingress.enabled=false

# ---------------------------------------------------------------------------
# Roles config: all authenticated users get viewer; admins get editor
# Applied as a ConfigMap that Kite reads at startup
# ---------------------------------------------------------------------------
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kite-roles
  namespace: kube-system
data:
  roles.yaml: |
    roles:
      - name: viewer
        rules:
          - apiGroups: ["*"]
            resources: ["*"]
            verbs: ["get", "list", "watch"]
      - name: editor
        rules:
          - apiGroups: ["*"]
            resources: ["*"]
            verbs: ["*"]
    bindings:
      - role: viewer
        subjects:
          - kind: Group
            name: system:authenticated
EOF

# ---------------------------------------------------------------------------
# Traefik IngressRoute (+ optional Sablier middleware)
# ---------------------------------------------------------------------------
MIDDLEWARES=""
if [[ "${SABLIER}" == "true" ]]; then
  kubectl annotate deployment kite \
    -n "${KITE_NAMESPACE}" \
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
  name: kite
  namespace: ${KITE_NAMESPACE}
spec:
  entryPoints: [web]
  routes:
    - match: Host(\`${KITE_HOST}\`)
      kind: Rule
      services:
        - name: kite
          port: 8080
          namespace: ${KITE_NAMESPACE}
${MIDDLEWARES}
EOF

TRAEFIK_IP=$(kubectl get svc -n traefik traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<traefik-ip>")

echo ""
echo "Kite deployed at http://${KITE_HOST}"
echo "  Add to /etc/hosts: ${TRAEFIK_IP} ${KITE_HOST}"
echo "  First run: create your admin account in the UI."
echo "  Tip: connect additional clusters via Settings → Clusters using their kubeconfig."
