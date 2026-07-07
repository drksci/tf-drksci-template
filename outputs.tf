output "k3s_token" {
  description = "k3s cluster join token (add more worker nodes later)"
  value       = length(random_password.k3s_token) > 0 ? random_password.k3s_token[0].result : ""
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to kubeconfig on the primary node"
  value       = local.kubeconfig_remote_path[var.runtime]
}

output "primary_host" {
  description = "Primary node host"
  value       = var.primary_node.host
}

output "worker_hosts" {
  description = "Worker node hosts"
  value       = { for k, v in local.active_workers : k => v.host }
}

output "dagger_runner_host" {
  description = "Set _EXPERIMENTAL_DAGGER_RUNNER_HOST to this on CI clients targeting this cluster"
  value       = var.enable_dagger ? "docker-container://dagger-engine" : ""
}

output "dockge_url" {
  description = "Dockge — Docker Compose stack manager"
  value       = var.enable_dashboard && var.enable_dockge ? module.dashboard[0].dockge_url : ""
}

output "kite_url" {
  description = "Kite — multi-cluster Kubernetes dashboard"
  value       = var.enable_dashboard && var.enable_kite ? module.dashboard[0].kite_url : ""
}

output "minio_console_url" {
  description = "MinIO web console"
  value       = var.enable_storage && var.enable_minio ? module.storage[0].minio_console_url : ""
}

output "minio_s3_url" {
  description = "MinIO S3 API endpoint"
  value       = var.enable_storage && var.enable_minio ? module.storage[0].minio_s3_url : ""
}

output "longhorn_url" {
  description = "Longhorn volume manager UI"
  value       = var.enable_storage && var.enable_longhorn ? module.storage[0].longhorn_url : ""
}

output "pulse_url" {
  description = "Pulse — unified Docker + k8s monitoring"
  value       = var.enable_observability && var.enable_pulse ? module.observability[0].pulse_url : ""
}

output "polaris_url" {
  description = "Polaris — Kubernetes best-practices scorecard"
  value       = var.enable_observability && var.enable_polaris ? module.observability[0].polaris_url : ""
}

output "argocd_url" {
  description = "ArgoCD GitOps dashboard"
  value       = var.enable_argocd ? module.argocd[0].argocd_url : ""
}

output "homepage_url" {
  description = "Homepage — unified portal for all homelab services"
  value       = var.enable_homepage ? module.homepage[0].homepage_url : ""
}

output "registry_url" {
  description = "Local container registry URL"
  value       = var.enable_registry ? module.registry[0].registry_url : ""
}

output "registry_push_instructions" {
  description = "How to push images to the local registry"
  value       = var.enable_registry ? module.registry[0].push_instructions : ""
}

output "traefik_instructions" {
  description = "Next steps after deployment"
  value = var.enable_sablier ? join("\n", [
    "Traefik + Sablier deployed.",
    "Get Traefik IP: kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'",
    "Point DNS / Cloudflare Tunnel at that IP.",
    "Scale-to-zero: add middleware 'sablier-blocking@kubernetescrd' (ns: sablier) to IngressRoute resources.",
  ]) : "Sablier not enabled."
}
