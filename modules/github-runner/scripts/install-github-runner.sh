#!/usr/bin/env bash
# GitHub Actions self-hosted runner — runs in k8s via actions-runner-controller (ARC).
#
# Connects your GitHub org/repos to your homelab so Actions workflows run on iMac-1.
# Runners have direct access to: Docker socket, kubectl, Dagger engine, local registry.
#
# GitHub App auth (recommended, no token expiry):
#   1. Create a GitHub App: Settings → Developer settings → GitHub Apps
#   2. Permissions: Actions (read), Administration (read+write), Metadata (read)
#   3. Install the app on your org / repos
#   4. Download the private key (.pem), get the App ID and Installation ID
#   Set: GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID, GITHUB_APP_PRIVATE_KEY
#
# OR Personal Access Token (simpler for personal use):
#   Set: GITHUB_TOKEN (classic token, repo + workflow scopes)
#   Set: GITHUB_URL to https://github.com/<your-org-or-user>
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${GITHUB_URL:?GITHUB_URL is required (e.g. https://github.com/myorg)}"
: "${GITHUB_TOKEN:=}"
: "${GITHUB_APP_ID:=}"
: "${GITHUB_APP_INSTALLATION_ID:=}"
: "${GITHUB_APP_PRIVATE_KEY:=}"
: "${RUNNER_REPLICAS:=2}"
: "${RUNNER_LABELS:=homelab,self-hosted,linux}"

export KUBECONFIG

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller 2>/dev/null || true
helm repo update actions-runner-controller

kubectl create namespace arc-system 2>/dev/null || true

# Store credentials
if [[ -n "${GITHUB_APP_ID}" ]]; then
  kubectl create secret generic controller-manager \
    --namespace arc-system \
    --from-literal=github_app_id="${GITHUB_APP_ID}" \
    --from-literal=github_app_installation_id="${GITHUB_APP_INSTALLATION_ID}" \
    --from-literal=github_app_private_key="${GITHUB_APP_PRIVATE_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
  AUTH_VALUES=(
    --set authSecret.create=false
    --set authSecret.name=controller-manager
  )
else
  kubectl create secret generic controller-manager \
    --namespace arc-system \
    --from-literal=github_token="${GITHUB_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
  AUTH_VALUES=(
    --set authSecret.create=false
    --set authSecret.name=controller-manager
  )
fi

helm upgrade --install arc actions-runner-controller/actions-runner-controller \
  --namespace arc-system \
  --wait \
  --timeout 3m \
  "${AUTH_VALUES[@]}"

# RunnerDeployment — org-level runners available to all repos
# Runners get Docker socket + kubeconfig + Dagger env
kubectl apply -f - <<EOF
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: homelab-runners
  namespace: arc-system
spec:
  replicas: ${RUNNER_REPLICAS}
  template:
    spec:
      githubAPICredentialsFrom:
        secretRef:
          name: controller-manager
      repository: ""
      organization: "$(echo ${GITHUB_URL} | sed 's|https://github.com/||')"
      labels:
        - homelab
        - self-hosted
        - linux
      # Mount Docker socket so runners can build and push images
      dockerEnabled: true
      dockerdContainerResources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: "2"
          memory: 2Gi
      env:
        # Point Dagger at the homelab engine
        - name: _EXPERIMENTAL_DAGGER_RUNNER_HOST
          value: docker-container://dagger-engine
        # Push to local registry without TLS
        - name: DOCKER_BUILDKIT
          value: "1"
      volumeMounts:
        - name: kubeconfig
          mountPath: /home/runner/.kube
          readOnly: true
      volumes:
        - name: kubeconfig
          hostPath:
            path: /etc/rancher/k3s
            type: Directory
      resources:
        requests:
          cpu: 500m
          memory: 1Gi
        limits:
          cpu: "4"
          memory: 8Gi
EOF

echo ""
echo "GitHub Actions runner deployed"
echo "  Org/user: ${GITHUB_URL}"
echo "  Replicas: ${RUNNER_REPLICAS}"
echo "  Labels:   ${RUNNER_LABELS}"
echo ""
echo "Use in your workflow:"
echo "  jobs:"
echo "    build:"
echo "      runs-on: [self-hosted, homelab]"
echo "      steps:"
echo "        - uses: actions/checkout@v4"
echo "        - run: dagger call build --source ."
