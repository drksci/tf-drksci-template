terraform {
  required_version = ">= 1.6.0"
  # Uncomment to use remote state:
  # backend "s3" {
  #   bucket  = "my-homelab-tfstate"
  #   key     = "homelab-cicd/terraform.tfstate"
  #   region  = "ap-southeast-2"
  #   encrypt = true
  # }
}

module "homelab_cicd" {
  source = "../../"

  primary_node = {
    host             = var.primary_host
    user             = var.primary_user
    port             = var.primary_port
    private_key_path = var.primary_key_path
    os               = var.primary_os
  }

  worker_nodes = var.worker_nodes
  runtime      = var.runtime
  k8s_version  = var.k8s_version

  primary_cpu       = var.primary_cpu
  primary_memory_gb = var.primary_memory_gb
  primary_disk_gb   = var.primary_disk_gb

  # Dagger
  enable_dagger  = var.enable_dagger
  dagger_version = var.dagger_version

  # Docuum
  enable_docuum    = var.enable_docuum
  docuum_threshold = var.docuum_threshold

  # Traefik + Sablier
  enable_sablier           = var.enable_sablier
  sablier_session_duration = var.sablier_session_duration
  traefik_lb_ip            = var.traefik_lb_ip

  # Registry
  enable_registry         = var.enable_registry
  registry_hostname       = var.registry_hostname
  registry_storage_size   = var.registry_storage_size
  registry_retention_days = var.registry_retention_days

  # Dashboards
  enable_dashboard           = var.enable_dashboard
  enable_dockge              = var.enable_dockge
  enable_kite                = var.enable_kite
  dockge_hostname            = var.dockge_hostname
  kite_hostname              = var.kite_hostname
  dockge_stacks_dir          = var.dockge_stacks_dir
  dashboard_session_duration = var.dashboard_session_duration

  # ArgoCD
  enable_argocd   = var.enable_argocd
  argocd_hostname = var.argocd_hostname

  # Homepage
  enable_homepage   = var.enable_homepage
  homepage_hostname = var.homepage_hostname

  # Storage
  enable_storage         = var.enable_storage
  enable_longhorn        = var.enable_longhorn
  enable_minio           = var.enable_minio
  minio_hostname         = var.minio_hostname
  minio_console_hostname = var.minio_console_hostname
  minio_root_user        = var.minio_root_user
  minio_root_password    = var.minio_root_password
  minio_storage_size     = var.minio_storage_size
  longhorn_hostname      = var.longhorn_hostname
  longhorn_replica_count = var.longhorn_replica_count

  # Observability
  enable_observability = var.enable_observability
  enable_pulse         = var.enable_pulse
  pulse_hostname       = var.pulse_hostname
  enable_polaris       = var.enable_polaris
  polaris_hostname     = var.polaris_hostname

  # Backup
  enable_backup         = var.enable_backup
  enable_velero         = var.enable_velero
  backup_schedule       = var.backup_schedule
  backup_retention_days = var.backup_retention_days
  enable_gdrive_sync    = var.enable_gdrive_sync
  gdrive_rclone_token   = var.gdrive_rclone_token
  gdrive_folder_id      = var.gdrive_folder_id

  # Exposure
  cloudflare_api_token  = var.cloudflare_api_token
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  cloudflare_domain     = var.cloudflare_domain
  tailscale_auth_key    = var.tailscale_auth_key
  tailscale_api_key     = var.tailscale_api_key
  tailscale_tailnet     = var.tailscale_tailnet
  internal_domain       = var.internal_domain
  argocd_exposure       = var.argocd_exposure
  kite_exposure         = var.kite_exposure
  homepage_exposure     = var.homepage_exposure

  # GitHub runner
  enable_github_runner = var.enable_github_runner
  github_url           = var.github_url
  github_token         = var.github_token

  # Sandbox
  enable_gvisor               = var.enable_gvisor
  enable_kata                 = var.enable_kata
  container_runtime_interface = var.container_runtime_interface

  # BotKube
  enable_botkube      = var.enable_botkube
  botkube_webhook_url = var.botkube_webhook_url
  botkube_platform    = var.botkube_platform
  botkube_channel     = var.botkube_channel
}
