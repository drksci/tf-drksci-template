# Single-node macOS — standard iMac setup with Colima.
# Everything enabled except Cloudflare, GitHub runner, and Google Drive sync.
# Good for: primary homelab, single iMac, Tailscale on free tier.
#
# Prerequisites:
#   - Remote Login enabled on iMac (System Settings → Sharing)
#   - SSH key copied: ssh-copy-id -i ~/.ssh/id_rsa.pub blake@192.168.1.10
#   - Tailscale auth key from tailscale.com/settings/keys (reusable, ephemeral)

primary_host     = "192.168.1.10"   # iMac LAN IP
primary_user     = "blake"
primary_os       = "macos"
primary_key_path = "~/.ssh/id_rsa"

primary_cpu       = 6
primary_memory_gb = 12
primary_disk_gb   = 80

runtime     = "colima"
k8s_version = "v1.30.5"

worker_nodes = {}

enable_sablier           = true
sablier_session_duration = "15m"
traefik_lb_ip            = ""   # set after first deploy: mise run output | grep traefik

enable_dagger           = true
dagger_version          = ""
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
longhorn_replica_count = 1
minio_hostname         = "s3.drksci.local"
minio_console_hostname = "minio.drksci.local"
minio_root_user        = "admin"
minio_root_password    = "CHANGE_ME_MIN_8_CHARS"
minio_data_path        = "/opt/minio/data"
longhorn_exposure      = "tailnet"
minio_console_exposure = "tailnet"

enable_observability = true
enable_pulse         = true
pulse_hostname       = "pulse.drksci.local"
enable_polaris       = true
polaris_hostname     = "polaris.drksci.local"

enable_backup         = true
enable_velero         = true
backup_schedule       = "0 3 * * *"
backup_retention_days = 7
enable_gdrive_sync    = false
gdrive_rclone_token   = ""
gdrive_folder_id      = ""

cloudflare_api_token = ""

tailscale_auth_key    = "tskey-auth-REPLACE"   # tailscale.com/settings/keys
tailscale_api_key     = ""                      # optional: enables ACL management
tailscale_tailnet     = ""                      # optional: your tailnet name

enable_github_runner = false
github_url           = ""
github_token         = ""

enable_botkube = false
