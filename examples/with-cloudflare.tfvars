# With Cloudflare — ArgoCD and homepage exposed publicly via Cloudflare Tunnel.
# MinIO and admin UIs remain internal/tailnet only.
# Good for: accessing ArgoCD from outside the home network without VPN.
#
# Prerequisites:
#   - Domain managed by Cloudflare (e.g. drksci.com)
#   - CF API token with Zone:Edit + Tunnel:Edit permissions
#   - Tunnel created at one.dash.cloudflare.com → Zero Trust → Tunnels
#
# Get values from: dash.cloudflare.com → right sidebar (Account/Zone IDs)

primary_host     = "192.168.1.10"
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
traefik_lb_ip            = "192.168.1.10"

enable_dagger   = true
enable_docuum   = true
enable_registry = true
registry_hostname       = "registry.drksci.local"
registry_storage_size   = "40Gi"
registry_retention_days = 30
enable_gvisor = true

enable_dashboard           = true
enable_dockge              = true
enable_kite                = true
dockge_hostname            = "dockge.drksci.local"
kite_hostname              = "kite.drksci.local"
dockge_stacks_dir          = "/opt/stacks"
dashboard_session_duration = "30m"

enable_argocd   = true
argocd_hostname = "argocd.drksci.com"   # public hostname via CF tunnel
argocd_exposure = "public"

enable_homepage   = true
homepage_hostname = "home.drksci.com"   # public landing page
homepage_exposure = "public"

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

# Cloudflare — all required when argocd_exposure or homepage_exposure = "public"
cloudflare_api_token  = "REPLACE_CF_API_TOKEN"
cloudflare_account_id = "REPLACE_CF_ACCOUNT_ID"
cloudflare_zone_id    = "REPLACE_CF_ZONE_ID"
cloudflare_domain     = "drksci.com"

tailscale_auth_key = "tskey-auth-REPLACE"

enable_github_runner = false
github_url           = ""
github_token         = ""

enable_botkube = false
