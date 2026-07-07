#!/usr/bin/env bash
# Exposure — wires public services through Cloudflare Tunnel and tailnet
# services through Tailscale operator.
#
# PUBLIC:  CF Edge → cloudflared pod → Traefik → internal service
#          + extra Traefik IngressRoute matching the public hostname
#          + Cloudflare DNS CNAME (created by cloudflare.tf Terraform provider)
#
# TAILNET: Tailscale operator creates <slug>.<tailnet>.ts.net
#          via a standard k8s Ingress with ingressClassName: tailscale
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${CF_TUNNEL_TOKEN:=}"
: "${TAILSCALE_AUTH_KEY:=}"
: "${PUBLIC_SERVICES_JSON:={}}"   # {"argocd":{"public_hostname":"argocd.blake.id.au","svc_ns":"argocd","svc_name":"argocd-server","svc_port":80},...}
: "${TAILNET_SERVICES_JSON:={}}"  # same shape, no public_hostname needed

export KUBECONFIG

if ! command -v jq &>/dev/null; then
  apt-get install -y jq 2>/dev/null || yum install -y jq 2>/dev/null || brew install jq 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Cloudflare Tunnel — cloudflared deployment
# ---------------------------------------------------------------------------

if [[ -n "${CF_TUNNEL_TOKEN}" ]]; then
  echo "==> Deploying cloudflared (Cloudflare Tunnel agent)"

  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cloudflare
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-token
  namespace: cloudflare
type: Opaque
stringData:
  token: "${CF_TUNNEL_TOKEN}"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflare
  labels:
    app: cloudflared
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      terminationGracePeriodSeconds: 30
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --no-autoupdate
        - --metrics
        - 0.0.0.0:2000
        - run
        - --token
        - \$(TUNNEL_TOKEN)
        env:
        - name: TUNNEL_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloudflared-token
              key: token
        resources:
          requests:
            memory: 64Mi
            cpu: 10m
          limits:
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /ready
            port: 2000
          initialDelaySeconds: 10
          periodSeconds: 10
EOF

  # Create public IngressRoutes for each public service.
  # cloudflared routes all CF traffic → Traefik; Traefik routes by Host header.
  # These IngressRoutes match the *public* hostname alongside the internal one.
  echo "${PUBLIC_SERVICES_JSON}" | jq -r '
    to_entries[] |
    "\(.key)|\(.value.public_hostname)|\(.value.svc_ns)|\(.value.svc_name)|\(.value.svc_port)"
  ' | while IFS='|' read -r slug hostname svc_ns svc_name svc_port; do
    [[ -z "$slug" ]] && continue
    echo "  IngressRoute: ${hostname} → ${svc_name}.${svc_ns}:${svc_port}"
    kubectl apply -f - <<MANIFEST
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ${slug}-public
  namespace: ${svc_ns}
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`${hostname}\`)
      kind: Rule
      services:
        - name: ${svc_name}
          port: ${svc_port}
MANIFEST
  done

  echo "cloudflared deployed — public services routed via CF tunnel"
fi

# ---------------------------------------------------------------------------
# Tailscale operator + tailnet Ingress resources
# ---------------------------------------------------------------------------

if [[ -n "${TAILSCALE_AUTH_KEY}" ]]; then
  echo "==> Deploying Tailscale operator"

  if ! command -v helm &>/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi

  kubectl create namespace tailscale 2>/dev/null || true

  kubectl create secret generic tailscale-auth \
    --from-literal=TS_AUTHKEY="${TAILSCALE_AUTH_KEY}" \
    --namespace tailscale \
    --dry-run=client -o yaml | kubectl apply -f -

  helm repo add tailscale https://pkgs.tailscale.com/helmcharts 2>/dev/null || true
  helm repo update tailscale

  helm upgrade --install tailscale-operator tailscale/tailscale-operator \
    --namespace tailscale \
    --wait \
    --timeout 3m \
    --set operatorConfig.hostname="homelab-operator" \
    --set oauth.clientId="" \
    --set oauth.clientSecret="" \
    --set-string extraEnv[0].name=TS_AUTHKEY \
    --set-string extraEnv[0].valueFrom.secretKeyRef.name=tailscale-auth \
    --set-string extraEnv[0].valueFrom.secretKeyRef.key=TS_AUTHKEY

  # Create Tailscale Ingress for each tailnet service.
  # Operator watches these and provisions a node on your tailnet.
  # Result: <slug>.<tailnet>.ts.net with valid HTTPS cert.
  echo "${TAILNET_SERVICES_JSON}" | jq -r '
    to_entries[] |
    "\(.key)|\(.value.svc_ns)|\(.value.svc_name)|\(.value.svc_port)"
  ' | while IFS='|' read -r slug svc_ns svc_name svc_port; do
    [[ -z "$slug" ]] && continue
    echo "  Tailnet Ingress: ${slug} → ${svc_name}.${svc_ns}:${svc_port}"
    kubectl apply -f - <<MANIFEST
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${slug}-tailscale
  namespace: ${svc_ns}
  annotations:
    tailscale.com/funnel: "false"
spec:
  ingressClassName: tailscale
  rules:
  - host: ${slug}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${svc_name}
            port:
              number: ${svc_port}
  tls:
  - hosts:
    - ${slug}
MANIFEST
  done

  echo "Tailscale operator deployed — tailnet services available as <slug>.<tailnet>.ts.net"
fi

echo ""
echo "Exposure wiring complete."
[[ -n "${CF_TUNNEL_TOKEN}" ]] && echo "  Public:  https://<subdomain>.${CLOUDFLARE_DOMAIN:-yourdomain.com}"
[[ -n "${TAILSCALE_AUTH_KEY}" ]] && echo "  Tailnet: https://<slug>.<tailnet>.ts.net"
