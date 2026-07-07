#!/usr/bin/env bash
# Retention detector — checks PVCs annotated with retention.homelab/ttl
# and alerts via webhook when TTL has elapsed. Never auto-deletes.
set -euo pipefail

: "${KUBECONFIG:=/etc/rancher/k3s/k3s.yaml}"
: "${ALERT_WEBHOOK_URL:=}"   # Discord/Slack webhook, or empty to just log
: "${CHECK_SCHEDULE:=0 8 * * *}"  # 8am daily

export KUBECONFIG

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: retention-detector
  namespace: default
data:
  check.sh: |
    #!/usr/bin/env sh
    set -e

    now=$(date +%s)
    expired=""
    expiring_soon=""  # within 7 days

    kubectl get pvc -A \
      -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.metadata.annotations.retention\.homelab/ttl}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}' \
    | while IFS=$'\t' read -r ns name ttl created; do
      [ -z "$ttl" ] && continue
      [ "$ttl" = "infinite" ] && continue

      # Parse TTL: 7d, 30d, 6m, 1y
      unit="${ttl##*[0-9]}"
      num="${ttl%%[a-z]*}"
      case "$unit" in
        d) ttl_sec=$((num * 86400)) ;;
        m) ttl_sec=$((num * 86400 * 30)) ;;
        y) ttl_sec=$((num * 86400 * 365)) ;;
        *) echo "Unknown TTL unit for $ns/$name: $ttl"; continue ;;
      esac

      created_sec=$(date -d "$created" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" +%s 2>/dev/null)
      expires_sec=$((created_sec + ttl_sec))
      remaining=$((expires_sec - now))

      if [ "$remaining" -le 0 ]; then
        age_days=$(( (now - created_sec) / 86400 ))
        echo "EXPIRED: $ns/$name (ttl=$ttl, age=${age_days}d)"
        expired="${expired}\n• \`$ns/$name\` — ttl=$ttl, age=${age_days}d"
      elif [ "$remaining" -le 604800 ]; then  # 7 days
        days_left=$((remaining / 86400))
        echo "EXPIRING SOON: $ns/$name (expires in ${days_left}d)"
        expiring_soon="${expiring_soon}\n• \`$ns/$name\` — expires in ${days_left}d"
      fi
    done

    # Alert
    if [ -n "$expired" ] || [ -n "$expiring_soon" ]; then
      msg="**Retention check** — $(date -u +%Y-%m-%d)"
      [ -n "$expired" ] && msg="${msg}\n\n:x: **Expired PVCs** (manual review needed):${expired}"
      [ -n "$expiring_soon" ] && msg="${msg}\n\n:warning: **Expiring within 7 days**:${expiring_soon}"

      if [ -n "${ALERT_WEBHOOK_URL:-}" ]; then
        curl -sfX POST "${ALERT_WEBHOOK_URL}" \
          -H "Content-Type: application/json" \
          -d "{\"content\": \"$(echo "$msg" | sed 's/"/\\"/g')\"}"
      else
        echo "$msg"
      fi
    else
      echo "All PVCs within retention TTL"
    fi
EOF

# CronJob that runs the detector
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: retention-detector
  namespace: default
spec:
  schedule: "${CHECK_SCHEDULE}"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          serviceAccountName: retention-detector
          containers:
          - name: checker
            image: bitnami/kubectl:latest
            command: [sh, /scripts/check.sh]
            env:
            - name: ALERT_WEBHOOK_URL
              value: "${ALERT_WEBHOOK_URL}"
            volumeMounts:
            - name: scripts
              mountPath: /scripts
          volumes:
          - name: scripts
            configMap:
              name: retention-detector
              defaultMode: 0755
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: retention-detector
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: retention-detector
rules:
- apiGroups: [""]
  resources: [persistentvolumeclaims]
  verbs: [get, list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: retention-detector
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: retention-detector
subjects:
- kind: ServiceAccount
  name: retention-detector
  namespace: default
EOF

echo "Retention detector deployed (schedule: ${CHECK_SCHEDULE})"
echo ""
echo "Annotate PVCs to opt in:"
echo "  kubectl annotate pvc my-pvc retention.homelab/ttl=30d"
echo "  kubectl annotate pvc my-pvc retention.homelab/ttl=infinite  # never alerts"
echo ""
echo "Supported units: d (days), m (months), y (years)"
