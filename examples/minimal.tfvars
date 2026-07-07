# Minimal — fastest path to a running cluster.
# Skips: backup, Cloudflare, Tailscale, GitHub runner, gVisor, observability.
# Good for: first deploy, testing, resource-constrained hardware.
#
# Deploy:
#   cp examples/minimal.tfvars environments/lab/terraform.tfvars
#   mise run secrets-init && mise run secrets-encrypt
#   mise run init && mise run deploy

primary_host     = "192.168.1.10"   # iMac LAN IP
primary_user     = "blake"
primary_os       = "macos"
primary_key_path = "~/.ssh/id_rsa"

primary_cpu       = 4
primary_memory_gb = 8
primary_disk_gb   = 60

runtime     = "colima"
k8s_version = "v1.30.5"

worker_nodes = {}

enable_sablier           = true
sablier_session_duration = "15m"
traefik_lb_ip            = ""

enable_dagger   = false
enable_docuum   = true
docuum_threshold = "7 days"
enable_registry = false
enable_gvisor   = false
enable_kata     = false

enable_dashboard           = true
enable_dockge              = true
enable_kite                = true
dockge_hostname            = "dockge.drksci.local"
kite_hostname              = "kite.drksci.local"
dockge_stacks_dir          = "/opt/stacks"
dashboard_session_duration = "30m"

enable_argocd   = false
enable_homepage = false

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

enable_observability = false
enable_backup        = false

cloudflare_api_token = ""
tailscale_auth_key   = ""

enable_github_runner = false
github_url           = ""
github_token         = ""

enable_botkube = false
