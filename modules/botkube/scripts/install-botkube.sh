#!/usr/bin/env bash
# Deploy BotKube — Kubernetes event notifications + AI-assisted kubectl in chat.
# Sends pod crashes, OOMKills, node events etc. to Discord/Slack/Mattermost.
# Optionally allows kubectl / helm commands from the chat channel.
# https://botkube.io/
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${PLATFORM:=discord}"
: "${WEBHOOK_URL:?WEBHOOK_URL is required}"
: "${CHANNEL:=homelab-alerts}"
: "${CLUSTER_NAME:=homelab}"
: "${ENABLE_KUBECTL:=true}"
: "${ENABLE_HELM:=false}"

export KUBECONFIG

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

helm repo add botkube https://charts.botkube.io 2>/dev/null || true
helm repo update botkube

# Build platform-specific values
case "${PLATFORM}" in
  discord)
    COMM_VALUES=(
      --set "communications.default-group.discord.enabled=true"
      --set "communications.default-group.discord.token="
      --set "communications.default-group.discord.botID="
      --set "communications.default-group.discord.channels.default.notification.disabled=false"
      --set "communications.default-group.discord.channels.default.name=${CHANNEL}"
    )
    ;;
  slack)
    COMM_VALUES=(
      --set "communications.default-group.socketSlack.enabled=true"
      --set "communications.default-group.socketSlack.appToken="
      --set "communications.default-group.socketSlack.botToken="
      --set "communications.default-group.socketSlack.channels.default.name=${CHANNEL}"
    )
    ;;
  mattermost)
    COMM_VALUES=(
      --set "communications.default-group.mattermost.enabled=true"
      --set "communications.default-group.mattermost.url=${WEBHOOK_URL}"
      --set "communications.default-group.mattermost.token="
      --set "communications.default-group.mattermost.team=homelab"
      --set "communications.default-group.mattermost.channels.default.name=${CHANNEL}"
    )
    ;;
esac

# Incoming webhook for simplified setup (Discord/Slack incoming webhooks)
# BotKube supports webhook-based sinks as a simpler alternative to bot tokens
helm upgrade --install botkube botkube/botkube \
  --namespace botkube \
  --create-namespace \
  --wait \
  --timeout 3m \
  --set clusterName="${CLUSTER_NAME}" \
  --set settings.clusterName="${CLUSTER_NAME}" \
  --set "communications.default-group.webhook.enabled=true" \
  --set "communications.default-group.webhook.url=${WEBHOOK_URL}" \
  --set "executors.kubectl.config.enabled=${ENABLE_KUBECTL}" \
  --set "executors.helm-executor.helm.enabled=${ENABLE_HELM}" \
  --set "sources.k8s-events.kubernetes.enabled=true" \
  --set "sources.k8s-events.kubernetes.events[0].type=error" \
  --set "sources.k8s-events.kubernetes.events[1].type=warning" \
  --set "sources.k8s-events.kubernetes.events[2].type=create" \
  "${COMM_VALUES[@]}"

echo ""
echo "BotKube deployed (platform: ${PLATFORM}, channel: ${CHANNEL})"
echo "  You will now receive alerts for:"
echo "    - Pod crashes / OOMKills"
echo "    - Node conditions (NotReady, pressure)"
echo "    - Deployment failures"
echo "    - PVC issues"
if [[ "${ENABLE_KUBECTL}" == "true" ]]; then
  echo ""
  echo "  kubectl executor enabled — run commands from ${CHANNEL}:"
  echo "    @Botkube kubectl get pods -A"
  echo "    @Botkube kubectl describe pod <name>"
fi
