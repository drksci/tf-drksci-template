# ---------------------------------------------------------------------------
# k3s / podman cluster join token (pre-generated; stored in Terraform state)
# ---------------------------------------------------------------------------

resource "random_password" "k3s_token" {
  count   = contains(["k3s", "podman"], var.runtime) ? 1 : 0
  length  = 48
  special = false
}

# ---------------------------------------------------------------------------
# Bootstrap — OS-level dependencies on every node
# ---------------------------------------------------------------------------

module "bootstrap_primary" {
  source = "./modules/bootstrap"

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout
}

module "bootstrap_workers" {
  for_each = local.active_workers
  source   = "./modules/bootstrap"

  host             = each.value.host
  user             = each.value.user
  port             = each.value.port
  private_key_path = each.value.private_key_path
  password         = each.value.password
  os               = each.value.os
  ssh_timeout      = var.ssh_timeout
}

# ---------------------------------------------------------------------------
# Container runtime + Kubernetes — primary node
# ---------------------------------------------------------------------------

module "runtime_primary" {
  source     = "./modules/runtime"
  depends_on = [module.bootstrap_primary]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  runtime                     = var.runtime
  role                        = "server"
  k3s_token                   = length(random_password.k3s_token) > 0 ? random_password.k3s_token[0].result : ""
  k3s_release                 = local.k3s_release
  k8s_version                 = var.k8s_version
  microk8s_channel            = var.microk8s_channel
  container_runtime_interface = var.container_runtime_interface
  cpu                         = var.primary_cpu
  memory_gb                   = var.primary_memory_gb
  disk_gb                     = var.primary_disk_gb
}

# ---------------------------------------------------------------------------
# Container runtime — worker nodes (k3s and microk8s)
# ---------------------------------------------------------------------------

module "runtime_workers" {
  for_each   = local.active_workers
  source     = "./modules/runtime"
  depends_on = [module.runtime_primary, module.bootstrap_workers]

  host             = each.value.host
  user             = each.value.user
  port             = each.value.port
  private_key_path = each.value.private_key_path
  password         = each.value.password
  os               = each.value.os
  ssh_timeout      = var.ssh_timeout

  runtime          = var.runtime
  role             = "agent"
  k3s_token        = length(random_password.k3s_token) > 0 ? random_password.k3s_token[0].result : ""
  k3s_release      = local.k3s_release
  k8s_version      = var.k8s_version
  microk8s_channel = var.microk8s_channel
  k3s_server_url   = "https://${var.primary_node.host}:6443"
}

# ---------------------------------------------------------------------------
# Dagger CI/CD engine
# ---------------------------------------------------------------------------

module "dagger" {
  count      = var.enable_dagger ? 1 : 0
  source     = "./modules/dagger"
  depends_on = [module.runtime_primary]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  dagger_version = var.dagger_version
  docker_socket  = local.docker_socket[var.runtime]
}

# ---------------------------------------------------------------------------
# Docuum — LRU Docker image pruning
# ---------------------------------------------------------------------------

module "docuum" {
  count      = var.enable_docuum ? 1 : 0
  source     = "./modules/docuum"
  depends_on = [module.runtime_primary]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  docker_socket = local.docker_socket[var.runtime]
  threshold     = var.docuum_threshold
}

# ---------------------------------------------------------------------------
# Dashboards — Dockge (Docker Compose) + Headlamp (k8s)
# ---------------------------------------------------------------------------

module "dashboard" {
  count      = var.enable_dashboard ? 1 : 0
  source     = "./modules/dashboard"
  depends_on = [module.sablier]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path          = local.kubeconfig_remote_path[var.runtime]
  enable_dockge            = var.enable_dockge
  enable_kite              = var.enable_kite
  dockge_hostname          = var.dockge_hostname
  kite_hostname            = var.kite_hostname
  dockge_stacks_dir        = var.dockge_stacks_dir
  sablier_enabled          = var.enable_sablier
  sablier_session_duration = var.dashboard_session_duration
}

# ---------------------------------------------------------------------------
# Exposure — Cloudflare Tunnel (public) + Tailscale operator (tailnet)
# ---------------------------------------------------------------------------

module "exposure" {
  count      = local.cf_enabled || local.tailscale_enabled ? 1 : 0
  source     = "./modules/exposure"
  depends_on = [module.sablier, module.dashboard, module.argocd, module.storage, module.observability]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path       = local.kubeconfig_remote_path[var.runtime]
  cf_tunnel_token       = local.cf_enabled ? cloudflare_zero_trust_tunnel_cloudflared.homelab[0].tunnel_token : ""
  tailscale_auth_key    = var.tailscale_auth_key
  public_services_json  = local.public_services_json
  tailnet_services_json = local.tailnet_services_json
  cloudflare_domain     = var.cloudflare_domain
}

# ---------------------------------------------------------------------------
# DNS — dnsmasq Compose stack: resolves *.drksci.local across the LAN
# Enabled when traefik_lb_ip is set; disabled until you know the LB IP.
# ---------------------------------------------------------------------------

module "dns" {
  count      = var.traefik_lb_ip != "" ? 1 : 0
  source     = "./modules/dns"
  depends_on = [module.exposure]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  traefik_lb_ip = var.traefik_lb_ip
  domain        = var.internal_domain
  stacks_dir    = var.dockge_stacks_dir
}

# ---------------------------------------------------------------------------
# Backup — Velero + rclone → Google Drive
# ---------------------------------------------------------------------------

module "backup" {
  count      = var.enable_backup ? 1 : 0
  source     = "./modules/backup"
  depends_on = [module.storage]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path       = local.kubeconfig_remote_path[var.runtime]
  enable_velero         = var.enable_velero
  minio_access_key      = var.minio_root_user
  minio_secret_key      = var.minio_root_password
  backup_schedule       = var.backup_schedule
  backup_retention_days = var.backup_retention_days
  enable_gdrive_sync    = var.enable_gdrive_sync
  gdrive_rclone_token   = var.gdrive_rclone_token
  gdrive_folder_id      = var.gdrive_folder_id
  gdrive_sync_schedule  = var.gdrive_sync_schedule
}

# ---------------------------------------------------------------------------
# GitHub Actions self-hosted runner
# ---------------------------------------------------------------------------

module "github_runner" {
  count      = var.enable_github_runner && var.github_url != "" ? 1 : 0
  source     = "./modules/github-runner"
  depends_on = [module.runtime_primary]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path            = local.kubeconfig_remote_path[var.runtime]
  github_url                 = var.github_url
  github_token               = var.github_token
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
  runner_replicas            = var.github_runner_replicas
}

# ---------------------------------------------------------------------------
# ArgoCD — GitOps continuous delivery
# ---------------------------------------------------------------------------

module "argocd" {
  count      = var.enable_argocd ? 1 : 0
  source     = "./modules/argocd"
  depends_on = [module.sablier]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path          = local.kubeconfig_remote_path[var.runtime]
  argocd_hostname          = var.argocd_hostname
  argocd_version           = var.argocd_version
  sablier_enabled          = false # CD engine must stay up for git webhooks
  sablier_session_duration = var.dashboard_session_duration
}

# ---------------------------------------------------------------------------
# Storage — Longhorn (volumes) + MinIO (S3)
# ---------------------------------------------------------------------------

module "storage" {
  count      = var.enable_storage ? 1 : 0
  source     = "./modules/storage"
  depends_on = [module.sablier]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path        = local.kubeconfig_remote_path[var.runtime]
  enable_longhorn        = var.enable_longhorn
  enable_minio           = var.enable_minio
  minio_hostname         = var.minio_hostname
  minio_console_hostname = var.minio_console_hostname
  minio_root_user        = var.minio_root_user
  minio_root_password    = var.minio_root_password
  dockge_stacks_dir      = var.dockge_stacks_dir
  longhorn_hostname      = var.longhorn_hostname
  longhorn_replica_count = var.longhorn_replica_count
}

# ---------------------------------------------------------------------------
# BotKube — cluster event notifications in Discord/Slack
# ---------------------------------------------------------------------------

module "botkube" {
  count      = var.enable_botkube ? 1 : 0
  source     = "./modules/botkube"
  depends_on = [module.runtime_primary]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path         = local.kubeconfig_remote_path[var.runtime]
  notification_platform   = var.botkube_platform
  webhook_url             = var.botkube_webhook_url
  channel_name            = var.botkube_channel
  cluster_name            = var.botkube_cluster_name
  enable_kubectl_executor = true
}

# ---------------------------------------------------------------------------
# Sandbox runtimes — gVisor and/or Kata as optional k8s RuntimeClasses
# ---------------------------------------------------------------------------

module "sandbox" {
  count      = (var.enable_gvisor || var.enable_kata) && var.primary_node.os != "macos" ? 1 : 0
  source     = "./modules/sandbox"
  depends_on = [module.runtime_primary]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path = local.kubeconfig_remote_path[var.runtime]
  enable_gvisor   = var.enable_gvisor
  enable_kata     = var.enable_kata
  kata_hypervisor = var.kata_hypervisor
}

# ---------------------------------------------------------------------------
# Homepage — unified portal with live widgets for all services
# ---------------------------------------------------------------------------

module "homepage" {
  count      = var.enable_homepage ? 1 : 0
  source     = "./modules/homepage"
  depends_on = [module.sablier, module.storage, module.observability, module.dashboard]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path        = local.kubeconfig_remote_path[var.runtime]
  homepage_hostname      = var.homepage_hostname
  cluster_name           = var.botkube_cluster_name
  minio_hostname         = var.minio_hostname
  minio_console_hostname = var.minio_console_hostname
  minio_access_key       = var.minio_root_user
  minio_secret_key       = var.enable_minio ? var.minio_root_password : ""
  longhorn_hostname      = var.longhorn_hostname
  kite_hostname          = var.kite_hostname
  dockge_hostname        = var.dockge_hostname
  pulse_hostname         = var.pulse_hostname
  polaris_hostname       = var.polaris_hostname
  registry_hostname      = var.registry_hostname
}

# ---------------------------------------------------------------------------
# Observability — Pulse (monitoring) + Polaris (best-practices audit)
# ---------------------------------------------------------------------------

module "observability" {
  count      = var.enable_observability ? 1 : 0
  source     = "./modules/observability"
  depends_on = [module.sablier]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path          = local.kubeconfig_remote_path[var.runtime]
  enable_pulse             = var.enable_pulse
  pulse_hostname           = var.pulse_hostname
  enable_polaris           = var.enable_polaris
  polaris_hostname         = var.polaris_hostname
  sablier_enabled          = var.enable_sablier
  sablier_session_duration = var.dashboard_session_duration
}

# ---------------------------------------------------------------------------
# Local container registry (image hosting for CI/CD and deployments)
# ---------------------------------------------------------------------------

module "registry" {
  count      = var.enable_registry ? 1 : 0
  source     = "./modules/registry"
  depends_on = [module.sablier] # needs Traefik CRDs

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path       = local.kubeconfig_remote_path[var.runtime]
  registry_hostname     = var.registry_hostname
  registry_storage_size = var.registry_storage_size
  retention_days        = var.registry_retention_days
}

# ---------------------------------------------------------------------------
# Sablier + Traefik — scale-to-zero ingress
# ---------------------------------------------------------------------------

module "sablier" {
  count      = var.enable_sablier ? 1 : 0
  source     = "./modules/sablier"
  depends_on = [module.runtime_primary, module.dagger, module.docuum]

  host             = var.primary_node.host
  user             = var.primary_node.user
  port             = var.primary_node.port
  private_key_path = var.primary_node.private_key_path
  password         = var.primary_node.password
  os               = var.primary_node.os
  ssh_timeout      = var.ssh_timeout

  kubeconfig_path  = local.kubeconfig_remote_path[var.runtime]
  runtime          = var.runtime
  sablier_version  = var.sablier_version
  traefik_version  = var.traefik_version
  session_duration = var.sablier_session_duration
  traefik_lb_ip    = var.traefik_lb_ip
}
