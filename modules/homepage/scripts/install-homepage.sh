#!/usr/bin/env bash
# Homepage — unified service portal with live API widgets for all homelab services.
# Pulls live stats from MinIO (buckets/storage), Longhorn (volumes), Traefik (routes),
# k8s (pod counts), Docker (container counts). Each tile links to the management UI.
# https://github.com/gethomepage/homepage
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${HOMEPAGE_HOSTNAME:=home.homelab.local}"
: "${CLUSTER_NAME:=homelab}"

# Service hostnames (used for widget API calls and tile hrefs)
: "${MINIO_HOSTNAME:=s3.homelab.local}"
: "${MINIO_CONSOLE_HOSTNAME:=minio.homelab.local}"
: "${MINIO_ACCESS_KEY:=admin}"
: "${MINIO_SECRET_KEY:=}"
: "${LONGHORN_HOSTNAME:=longhorn.homelab.local}"
: "${KITE_HOSTNAME:=kite.homelab.local}"
: "${DOCKGE_HOSTNAME:=dockge.homelab.local}"
: "${PULSE_HOSTNAME:=pulse.homelab.local}"
: "${POLARIS_HOSTNAME:=polaris.homelab.local}"
: "${REGISTRY_HOSTNAME:=registry.homelab.local}"
: "${ARGOCD_HOSTNAME:=argocd.homelab.local}"
: "${TRAEFIK_NAMESPACE:=traefik}"

CONFIG_DIR="${HOME}/.config/homepage"
mkdir -p "${CONFIG_DIR}"

# Detect Docker socket
DOCKER_SOCK=/var/run/docker.sock
[[ -S "$HOME/.colima/default/docker.sock" ]] && DOCKER_SOCK="$HOME/.colima/default/docker.sock"

# ---------------------------------------------------------------------------
# settings.yaml
# ---------------------------------------------------------------------------
cat > "${CONFIG_DIR}/settings.yaml" <<EOF
title: Homelab
favicon: https://kubernetes.io/images/favicon.png
theme: dark
color: slate
headerStyle: clean
layout:
  Cluster:
    style: row
    columns: 3
  Storage:
    style: row
    columns: 2
  Observability:
    style: row
    columns: 3
  Management:
    style: row
    columns: 2
EOF

# ---------------------------------------------------------------------------
# services.yaml — tiles with API widgets
# ---------------------------------------------------------------------------
cat > "${CONFIG_DIR}/services.yaml" <<EOF
- Cluster:
  - Kite:
      icon: kubernetes.png
      href: http://${KITE_HOSTNAME}
      description: Multi-cluster Kubernetes dashboard
      siteMonitor: http://${KITE_HOSTNAME}
      widget:
        type: kubernetes
        cluster: ${CLUSTER_NAME}

  - Traefik:
      icon: traefik.png
      href: http://traefik.${CLUSTER_NAME}.local
      description: Ingress / reverse proxy
      siteMonitor: http://${KITE_HOSTNAME}
      widget:
        type: traefik
        url: http://traefik.${TRAEFIK_NAMESPACE}.svc.cluster.local:9000

  - Dockge:
      icon: docker.png
      href: http://${DOCKGE_HOSTNAME}
      description: Docker Compose stack manager
      siteMonitor: http://${DOCKGE_HOSTNAME}

- Storage:
  - MinIO Console:
      icon: minio.png
      href: http://${MINIO_CONSOLE_HOSTNAME}
      description: S3 object storage — browse buckets, upload files, manage policies
      siteMonitor: http://${MINIO_CONSOLE_HOSTNAME}
$(if [[ -n "${MINIO_SECRET_KEY}" ]]; then cat <<WIDGET
      widget:
        type: minio
        url: http://${MINIO_HOSTNAME}
        accessKey: ${MINIO_ACCESS_KEY}
        secretKey: ${MINIO_SECRET_KEY}
WIDGET
fi)

  - Longhorn:
      icon: longhorn.png
      href: http://${LONGHORN_HOSTNAME}
      description: Distributed block storage — volumes, snapshots, backups
      siteMonitor: http://${LONGHORN_HOSTNAME}
      widget:
        type: longhorn
        url: http://longhorn-frontend.longhorn-system.svc.cluster.local

- Observability:
  - Pulse:
      icon: grafana.png
      href: http://${PULSE_HOSTNAME}
      description: Real-time Docker + Kubernetes monitoring
      siteMonitor: http://${PULSE_HOSTNAME}

  - Polaris:
      icon: kubernetes.png
      href: http://${POLARIS_HOSTNAME}
      description: Kubernetes best-practices scorecard
      siteMonitor: http://${POLARIS_HOSTNAME}

  - Registry:
      icon: docker.png
      href: http://${REGISTRY_HOSTNAME}
      description: Local container image registry
      siteMonitor: http://${REGISTRY_HOSTNAME}/v2/

- Management:
  - ArgoCD:
      icon: argocd.png
      href: http://${ARGOCD_HOSTNAME}
      description: GitOps — watches git, reconciles cluster state
      siteMonitor: http://${ARGOCD_HOSTNAME}
      widget:
        type: argocd
        url: http://${ARGOCD_HOSTNAME}

  - BotKube:
      icon: slack.png
      description: Cluster alerts → Discord/Slack
      siteMonitor: http://${KITE_HOSTNAME}

  - Dagger:
      icon: docker.png
      description: CI/CD engine (docker-container://dagger-engine)
      siteMonitor: http://${KITE_HOSTNAME}
EOF

# ---------------------------------------------------------------------------
# widgets.yaml — top bar system info
# ---------------------------------------------------------------------------
cat > "${CONFIG_DIR}/widgets.yaml" <<EOF
- resources:
    label: ${CLUSTER_NAME}
    cpu: true
    memory: true
    disk: /

- kubernetes:
    cluster:
      show: true
      cpu: true
      memory: true
      showLabel: true
      label: ${CLUSTER_NAME}
    nodes:
      show: true
      cpu: true
      memory: true
      showLabel: true

- datetime:
    text_size: xl
    format:
      dateStyle: short
      timeStyle: short
      hour12: false
EOF

# ---------------------------------------------------------------------------
# bookmarks.yaml — quick links
# ---------------------------------------------------------------------------
cat > "${CONFIG_DIR}/bookmarks.yaml" <<EOF
- Docs:
  - k3s docs:
    - icon: kubernetes.png
      href: https://docs.k3s.io
  - Longhorn docs:
    - icon: longhorn.png
      href: https://longhorn.io/docs
  - MinIO docs:
    - icon: minio.png
      href: https://min.io/docs
  - Traefik docs:
    - icon: traefik.png
      href: https://doc.traefik.io/traefik
EOF

# ---------------------------------------------------------------------------
# Run Homepage container
# ---------------------------------------------------------------------------
docker rm -f homepage 2>/dev/null || true

DOCKER_ARGS=(
  run -d
  --name homepage
  --restart unless-stopped
  -p "127.0.0.1:3000:3000"
  -v "${CONFIG_DIR}:/app/config"
)

# Docker socket for container discovery (auto-shows all running containers)
[[ -S "${DOCKER_SOCK}" ]] && DOCKER_ARGS+=(
  -v "${DOCKER_SOCK}:/var/run/docker.sock:ro"
)

# Kubeconfig for k8s widget
[[ -f "${KUBECONFIG}" ]] && DOCKER_ARGS+=(
  -v "${KUBECONFIG}:/app/config/kubernetes.yaml:ro"
  -e "HOMEPAGE_VAR_CLUSTER_NAME=${CLUSTER_NAME}"
)

DOCKER_ARGS+=("ghcr.io/gethomepage/homepage:latest")

docker "${DOCKER_ARGS[@]}"

echo "Homepage container started on 127.0.0.1:3000"

# Expose through Traefik
if kubectl --kubeconfig "${KUBECONFIG}" get ns traefik &>/dev/null 2>&1; then
  kubectl --kubeconfig "${KUBECONFIG}" apply -f - <<K8S
apiVersion: v1
kind: Service
metadata:
  name: homepage
  namespace: default
spec:
  type: ExternalName
  externalName: host.k3s.internal
  ports:
    - port: 3000
      targetPort: 3000
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: homepage
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`${HOMEPAGE_HOSTNAME}\`)
      kind: Rule
      services:
        - name: homepage
          port: 3000
K8S
  echo "Homepage: http://${HOMEPAGE_HOSTNAME}"
fi
