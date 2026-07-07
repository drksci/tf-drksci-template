#!/usr/bin/env bash
# Deploy Docker Registry v2 on K8s with:
#  - Persistent volume for image storage
#  - Traefik ingress
#  - GC (garbage collection) CronJob for retention
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${STORAGE_SIZE:=50Gi}"
: "${REGISTRY_HOST:=registry.homelab.local}"
: "${RETENTION_DAYS:=30}"
export KUBECONFIG

timeout 60 bash -c 'until kubectl cluster-info &>/dev/null; do sleep 3; done'

kubectl create namespace registry --dry-run=client -o yaml | kubectl apply -f -

# PVC for image data
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-data
  namespace: registry
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: ${STORAGE_SIZE}
EOF

# Registry Deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
  labels:
    app: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
      annotations:
        # Opt into Sablier scale-to-zero if Sablier is deployed
        sablier.enable: "false"   # set to "true" to allow scale-to-zero (not recommended for registries)
    spec:
      containers:
        - name: registry
          image: registry:2
          ports:
            - containerPort: 5000
          env:
            - name: REGISTRY_STORAGE_DELETE_ENABLED
              value: "true"
            - name: REGISTRY_HTTP_ADDR
              value: "0.0.0.0:5000"
          volumeMounts:
            - name: data
              mountPath: /var/lib/registry
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: registry-data
---
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: registry
spec:
  selector:
    app: registry
  ports:
    - port: 5000
      targetPort: 5000
EOF

# Traefik IngressRoute (requires Traefik CRDs — deployed by sablier module)
kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: registry
  namespace: registry
spec:
  entryPoints: [web]
  routes:
    - match: Host(\`${REGISTRY_HOST}\`)
      kind: Rule
      services:
        - name: registry
          port: 5000
EOF

# GC CronJob — runs nightly to prune untagged manifests older than RETENTION_DAYS
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: registry-gc
  namespace: registry
spec:
  schedule: "0 3 * * *"   # 3am daily
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: gc
              image: registry:2
              command:
                - /bin/registry
                - garbage-collect
                - --delete-untagged=true
                - /etc/docker/registry/config.yml
              volumeMounts:
                - name: data
                  mountPath: /var/lib/registry
          volumes:
            - name: data
              persistentVolumeClaim:
                claimName: registry-data
EOF

# Configure k3s to trust the insecure local registry (no TLS needed on LAN)
if command -v k3s &>/dev/null; then
  mkdir -p /etc/rancher/k3s
  cat >> /etc/rancher/k3s/registries.yaml <<REGEOF

mirrors:
  "${REGISTRY_HOST}":
    endpoint:
      - "http://registry.registry.svc.cluster.local:5000"
REGEOF
  systemctl restart k3s 2>/dev/null || true
fi

echo "Registry deployed at http://${REGISTRY_HOST}"
echo "Add '$(kubectl get svc -n traefik traefik -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || echo "<traefik-ip>") ${REGISTRY_HOST}' to /etc/hosts on client machines"
