# ---------------------------------------------------------------------------
# Node definitions
# ---------------------------------------------------------------------------

variable "primary_node" {
  description = "Primary node (k8s server / control-plane) SSH connection details"
  type = object({
    host             = string
    user             = string
    port             = optional(number, 22)
    private_key_path = optional(string, "~/.ssh/id_rsa")
    password         = optional(string, "")
    os               = optional(string, "linux") # "linux" | "macos"
  })
}

variable "worker_nodes" {
  description = "Additional k3s worker nodes (only used when runtime = k3s)"
  type = map(object({
    host             = string
    user             = string
    port             = optional(number, 22)
    private_key_path = optional(string, "~/.ssh/id_rsa")
    password         = optional(string, "")
    os               = optional(string, "linux")
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Container runtime
# ---------------------------------------------------------------------------

variable "runtime" {
  description = "Container runtime + K8s: colima (macOS), k3s, podman, or minikube"
  type        = string
  default     = "k3s"

  validation {
    condition     = contains(["colima", "k3s", "podman", "minikube", "microk8s"], var.runtime)
    error_message = "runtime must be one of: colima, k3s, podman, minikube, microk8s."
  }
}

variable "k8s_version" {
  description = "Kubernetes version (e.g. v1.30.5)"
  type        = string
  default     = "v1.30.5"
}

variable "primary_cpu" {
  description = "vCPU count for VM-based runtimes (colima, minikube)"
  type        = number
  default     = 4
}

variable "primary_memory_gb" {
  description = "RAM in GiB for VM-based runtimes"
  type        = number
  default     = 8
}

variable "primary_disk_gb" {
  description = "Disk in GiB for VM-based runtimes"
  type        = number
  default     = 60
}

# ---------------------------------------------------------------------------
# Dagger
# ---------------------------------------------------------------------------

variable "enable_dagger" {
  description = "Install Dagger CLI and run persistent engine"
  type        = bool
  default     = true
}

variable "dagger_version" {
  description = "Dagger CLI version (e.g. v0.13.3). Empty string = latest."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Docuum
# ---------------------------------------------------------------------------

variable "enable_docuum" {
  description = "Install Docuum LRU image pruning daemon"
  type        = bool
  default     = true
}

variable "docuum_threshold" {
  description = "LRU age threshold before images are pruned (e.g. '7 days', '12 hours')"
  type        = string
  default     = "7 days"
}

# ---------------------------------------------------------------------------
# Sablier + Traefik
# ---------------------------------------------------------------------------

variable "enable_sablier" {
  description = "Deploy Sablier (scale-to-zero) and Traefik ingress via Helm"
  type        = bool
  default     = true
}

variable "sablier_session_duration" {
  description = "Idle timeout before Sablier scales workload to zero"
  type        = string
  default     = "10m"
}

variable "sablier_version" {
  description = "Sablier Helm chart version. Empty = latest."
  type        = string
  default     = ""
}

variable "traefik_version" {
  description = "Traefik Helm chart version. Empty = latest."
  type        = string
  default     = ""
}

variable "traefik_lb_ip" {
  description = "Optional static LoadBalancer IP for Traefik (leave empty to use DHCP/assigned)"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Container registry
# ---------------------------------------------------------------------------

variable "enable_registry" {
  description = "Deploy a local Docker Registry v2 with PVC-backed storage and GC"
  type        = bool
  default     = true
}

variable "registry_hostname" {
  description = "DNS hostname for the registry (add to /etc/hosts or split-horizon DNS)"
  type        = string
  default     = "registry.drksci.local"
}

variable "registry_storage_size" {
  description = "PVC size for image storage"
  type        = string
  default     = "50Gi"
}

variable "registry_retention_days" {
  description = "Days before untagged manifests are GC'd"
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# Dashboards
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Dashboards
# ---------------------------------------------------------------------------

variable "enable_dashboard" {
  description = "Deploy Dockge (Docker Compose) + Kite (k8s dashboard)"
  type        = bool
  default     = true
}

variable "enable_dockge" {
  description = "Deploy Dockge — Docker Compose stack manager (host container)"
  type        = bool
  default     = true
}

variable "enable_kite" {
  description = "Deploy Kite — multi-cluster k8s dashboard (OAuth, Helm UI, Prometheus, AI)"
  type        = bool
  default     = true
}

variable "dockge_hostname" {
  type    = string
  default = "dockge.drksci.local"
}

variable "kite_hostname" {
  type    = string
  default = "kite.drksci.local"
}

variable "dockge_stacks_dir" {
  description = "Host path where Dockge stores Docker Compose stacks"
  type        = string
  default     = "/opt/stacks"
}

variable "dashboard_session_duration" {
  description = "Sablier idle timeout for dashboard UIs"
  type        = string
  default     = "30m"
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

variable "enable_storage" {
  description = "Deploy MinIO (S3) + Longhorn (volume manager)"
  type        = bool
  default     = true
}

variable "enable_minio" {
  type    = bool
  default = true
}

variable "enable_longhorn" {
  type    = bool
  default = true
}

variable "minio_hostname" {
  type    = string
  default = "s3.drksci.local"
}

variable "minio_console_hostname" {
  type    = string
  default = "minio.drksci.local"
}

variable "minio_root_user" {
  type    = string
  default = "admin"
}

variable "minio_root_password" {
  type      = string
  sensitive = true
}

variable "minio_storage_size" {
  type    = string
  default = "100Gi"
}

variable "longhorn_hostname" {
  type    = string
  default = "longhorn.drksci.local"
}

variable "longhorn_replica_count" {
  description = "Volume replicas: 1 for single-node, 2-3 for HA multi-node"
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# ArgoCD — GitOps continuous delivery
# ---------------------------------------------------------------------------

variable "enable_argocd" {
  description = "Deploy ArgoCD — GitOps CD, watches git repos and reconciles cluster state"
  type        = bool
  default     = true
}

variable "argocd_hostname" {
  type    = string
  default = "argocd.drksci.local"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version — empty means latest"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Homepage — unified portal with live service widgets
# ---------------------------------------------------------------------------

variable "enable_homepage" {
  description = "Deploy Homepage — unified portal with live MinIO/Longhorn/k8s/Docker widgets"
  type        = bool
  default     = true
}

variable "homepage_hostname" {
  type    = string
  default = "home.drksci.local"
}

# ---------------------------------------------------------------------------
# Observability — Pulse + Polaris + KubeShark (CLI on MacBook)
# ---------------------------------------------------------------------------

variable "enable_observability" {
  description = "Deploy Pulse (monitoring) + Polaris (best-practices dashboard)"
  type        = bool
  default     = true
}

variable "enable_pulse" {
  description = "Deploy Pulse — unified Docker + k8s real-time monitoring (host Docker container)"
  type        = bool
  default     = true
}

variable "pulse_hostname" {
  type    = string
  default = "pulse.drksci.local"
}

variable "enable_polaris" {
  description = "Deploy Polaris — Kubernetes best-practices scorecard dashboard"
  type        = bool
  default     = true
}

variable "polaris_hostname" {
  type    = string
  default = "polaris.drksci.local"
}

# ---------------------------------------------------------------------------
# BotKube — cluster alerts in Discord/Slack
# ---------------------------------------------------------------------------

variable "enable_botkube" {
  description = "Deploy BotKube for cluster event notifications in Discord/Slack/Mattermost"
  type        = bool
  default     = false
}

variable "botkube_platform" {
  description = "Chat platform: discord, slack, or mattermost"
  type        = string
  default     = "discord"
}

variable "botkube_webhook_url" {
  description = "Incoming webhook URL for the chat channel"
  type        = string
  default     = ""
  sensitive   = true
}

variable "botkube_channel" {
  type    = string
  default = "homelab-alerts"
}

variable "botkube_cluster_name" {
  type    = string
  default = "homelab"
}

# ---------------------------------------------------------------------------
# Sandbox runtimes (optional per-pod isolation via RuntimeClass)
# ---------------------------------------------------------------------------

variable "enable_gvisor" {
  description = "Install gVisor (runsc) — syscall sandbox, no KVM needed. Use runtimeClassName: gvisor on untrusted pods."
  type        = bool
  default     = true
}

variable "enable_kata" {
  description = "Install Kata Containers — VM-per-pod via KVM. Stronger than gVisor; requires hardware virtualisation."
  type        = bool
  default     = false
}

variable "kata_hypervisor" {
  description = "Kata hypervisor backend: qemu, cloud-hypervisor, or dragonball"
  type        = string
  default     = "qemu"
}

variable "container_runtime_interface" {
  description = "Low-level CRI for k3s: containerd (default, works with gVisor/Kata) or crio (OCI-focused, used by OpenShift)"
  type        = string
  default     = "containerd"
}

variable "microk8s_channel" {
  description = "MicroK8s snap channel (e.g. 1.30/stable)"
  type        = string
  default     = "1.30/stable"
}

# ---------------------------------------------------------------------------
# Exposure — internal | tailnet | public per service
# ---------------------------------------------------------------------------

variable "argocd_exposure" {
  type        = string
  default     = "internal"
  description = "internal | tailnet | public"
}
variable "kite_exposure" {
  type    = string
  default = "internal"
}
variable "dockge_exposure" {
  type    = string
  default = "internal"
}
variable "homepage_exposure" {
  type    = string
  default = "internal"
}
variable "minio_console_exposure" {
  type    = string
  default = "internal"
}
variable "longhorn_exposure" {
  type    = string
  default = "internal"
}
variable "registry_exposure" {
  type    = string
  default = "internal"
}
variable "pulse_exposure" {
  type    = string
  default = "internal"
}
variable "polaris_exposure" {
  type    = string
  default = "internal"
}

# ---------------------------------------------------------------------------
# Cloudflare — tunnel + auto DNS for public services
# ---------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token (Zone:Edit + Account:Tunnel:Edit)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_account_id" {
  type    = string
  default = ""
}

variable "cloudflare_zone_id" {
  description = "Zone ID for your domain in Cloudflare"
  type        = string
  default     = ""
}

variable "cloudflare_domain" {
  description = "Root domain managed in Cloudflare, e.g. blake.id.au"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Tailscale — tailnet exposure via k8s operator
# ---------------------------------------------------------------------------

variable "tailscale_auth_key" {
  description = "Tailscale auth key (generate at tailscale.com/settings/keys — use reusable+ephemeral)"
  type        = string
  default     = ""
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Backup — Velero (k8s) + rclone → Google Drive
# ---------------------------------------------------------------------------

variable "enable_backup" {
  type    = bool
  default = false
}

variable "enable_velero" {
  type    = bool
  default = true
}

variable "backup_schedule" {
  description = "Cron expression for Velero full backup"
  type        = string
  default     = "0 3 * * *"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "enable_gdrive_sync" {
  description = "Sync Velero backups to Google Drive via rclone"
  type        = bool
  default     = false
}

variable "gdrive_rclone_token" {
  description = "rclone Google Drive OAuth token (run: mise run backup-auth to generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gdrive_folder_id" {
  description = "Google Drive folder ID for backups (empty = My Drive root)"
  type        = string
  default     = ""
}

variable "gdrive_sync_schedule" {
  description = "Cron for rclone → GDrive sync (should be after backup_schedule)"
  type        = string
  default     = "0 4 * * *"
}

# ---------------------------------------------------------------------------
# GitHub Actions runner
# ---------------------------------------------------------------------------

variable "enable_github_runner" {
  type    = bool
  default = false
}

variable "github_url" {
  description = "GitHub org or user URL, e.g. https://github.com/myorg"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "Classic PAT with repo + workflow scopes (alternative to GitHub App)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_id" {
  type    = string
  default = ""
}
variable "github_app_installation_id" {
  type    = string
  default = ""
}
variable "github_app_private_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "github_runner_replicas" {
  type    = number
  default = 2
}

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

variable "ssh_timeout" {
  description = "SSH connection timeout string"
  type        = string
  default     = "5m"
}
