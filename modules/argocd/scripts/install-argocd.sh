#!/usr/bin/env bash
# ArgoCD — GitOps continuous delivery for Kubernetes.
# Watches git repos, reconciles cluster state, rolling deploys on commit.
# UI exposed via Traefik at ARGOCD_HOSTNAME.
# https://argoproj.github.io/cd
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${ARGOCD_HOSTNAME:=argocd.drksci.local}"
: "${SABLIER_ENABLED:=false}"
: "${SABLIER_SESSION_DURATION:=30m}"
: "${ARGOCD_VERSION:=}"   # empty = latest

export KUBECONFIG

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo

HELM_ARGS=(
  upgrade --install argocd argo/argo-cd
  --namespace argocd
  --create-namespace
  --wait
  --timeout 5m
  # Run insecure — Traefik terminates TLS, ArgoCD doesn't need its own cert
  --set server.extraArgs="{--insecure}"
  # Disable built-in ingress — Traefik IngressRoute handles routing
  --set server.ingress.enabled=false
  # Scale down non-essential replicas for homelab resource usage
  --set repoServer.replicas=1
  --set applicationSet.replicas=1
)

[[ -n "${ARGOCD_VERSION}" ]] && HELM_ARGS+=(--version "${ARGOCD_VERSION}")

helm "${HELM_ARGS[@]}"

# ---------------------------------------------------------------------------
# Traefik IngressRoute
# ---------------------------------------------------------------------------

# shellcheck disable=SC2034  # used inside kubectl heredoc below
MIDDLEWARE_REFS="[]"
if [[ "${SABLIER_ENABLED}" == "true" ]]; then
  # ArgoCD should NOT be behind Sablier — it needs to receive git webhooks
  # even when no human is looking at the UI. Leave it always-on.
  echo "NOTE: Skipping Sablier for ArgoCD — CD engine must always be running to receive git webhooks."
fi

kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd
  namespace: argocd
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`${ARGOCD_HOSTNAME}\`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
    # gRPC (argocd CLI) — same host, separate route for protocol detection
    - match: Host(\`${ARGOCD_HOSTNAME}\`) && Headers(\`Content-Type\`, \`application/grpc\`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
          scheme: h2c
EOF

# ---------------------------------------------------------------------------
# Print initial credentials
# ---------------------------------------------------------------------------
echo ""
echo "ArgoCD deployed — http://${ARGOCD_HOSTNAME}"
echo ""
echo "Initial admin credentials:"
echo "  Username: admin"
echo "  Password: $(kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo '(run: mise run argocd-password)')"
echo ""
echo "Change password on first login, then:"
echo "  kubectl delete secret argocd-initial-admin-secret -n argocd"
echo ""
echo "CLI login:"
echo "  argocd login ${ARGOCD_HOSTNAME} --username admin --insecure"
