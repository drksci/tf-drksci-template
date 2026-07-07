# Multi-node — primary iMac + second worker node.
# Longhorn replicas = 2 for HA storage across both nodes.
# Good for: adding a second Mac or a Linux box as a worker.

primary_host     = "192.168.1.10"
primary_user     = "blake"
primary_os       = "macos"
primary_key_path = "~/.ssh/id_rsa"

primary_cpu       = 6
primary_memory_gb = 12
primary_disk_gb   = 80

runtime     = "colima"
k8s_version = "v1.30.5"

worker_nodes = {
  "imac-2" = {
    host             = "192.168.1.11"
    user             = "blake"
    private_key_path = "~/.ssh/id_rsa"
    os               = "macos"
  }
  # "intel-box" = {
  #   host             = "192.168.1.20"
  #   user             = "ubuntu"
  #   private_key_path = "~/.ssh/id_rsa"
  #   os               = "linux"
  # }
}

enable_sablier           = true
sablier_session_duration = "15m"
traefik_lb_ip            = "192.168.1.10"

enable_dagger           = true
enable_docuum           = true
docuum_threshold        = "7 days"
enable_registry         = true
registry_hostname       = "registry.drksci.local"
registry_storage_size   = "80Gi"
registry_retention_days = 30
enable_gvisor           = true
enable_kata             = false

enable_dashboard           = true
enable_dockge              = true
enable_kite                = true
dockge_hostname            = "dockge.drksci.local"
kite_hostname              = "kite.drksci.local"
dockge_stacks_dir          = "/opt/stacks"
dashboard_session_duration = "30m"

enable_argocd   = true
argocd_hostname = "argocd.drksci.local"
argocd_exposure = "tailnet"

enable_homepage   = true
homepage_hostname = "home.drksci.local"
homepage_exposure = "internal"

enable_storage         = true
enable_longhorn        = true
enable_minio           = true
longhorn_hostname      = "longhorn.drksci.local"
longhorn_replica_count = 2   # HA: data replicated across both nodes
minio_hostname         = "s3.drksci.local"
minio_console_hostname = "minio.drksci.local"
minio_root_user        = "admin"
minio_root_password    = "CHANGE_ME_MIN_8_CHARS"
minio_data_path        = "/opt/minio/data"

enable_observability = true
enable_pulse         = true
pulse_hostname       = "pulse.drksci.local"
enable_polaris       = true
polaris_hostname     = "polaris.drksci.local"

enable_backup         = true
enable_velero         = true
backup_schedule       = "0 3 * * *"
backup_retention_days = 7
enable_gdrive_sync    = true
gdrive_rclone_token   = ""   # run: mise run backup-auth
gdrive_folder_id      = ""

cloudflare_api_token = ""
tailscale_auth_key   = "tskey-auth-REPLACE"

enable_github_runner = false
github_url           = ""
github_token         = ""

enable_botkube = false
