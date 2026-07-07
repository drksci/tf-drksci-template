variable "primary_host" {
  description = "IP or hostname of the primary (control-plane) node"
  type        = string
}

variable "primary_user" {
  type    = string
  default = "blake"
}

variable "primary_port" {
  type    = number
  default = 22
}

variable "primary_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "primary_os" {
  type    = string
  default = "linux"
}

variable "worker_nodes" {
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

variable "runtime" {
  type    = string
  default = "k3s"
}

variable "k8s_version" {
  type    = string
  default = "v1.30.5"
}

variable "primary_cpu" {
  type    = number
  default = 4
}

variable "primary_memory_gb" {
  type    = number
  default = 8
}

variable "primary_disk_gb" {
  type    = number
  default = 60
}

variable "enable_dagger" {
  type    = bool
  default = true
}

variable "dagger_version" {
  type    = string
  default = ""
}

variable "enable_docuum" {
  type    = bool
  default = true
}

variable "docuum_threshold" {
  type    = string
  default = "7 days"
}

variable "enable_sablier" {
  type    = bool
  default = true
}

variable "sablier_session_duration" {
  type    = string
  default = "15m"
}

variable "traefik_lb_ip" {
  type    = string
  default = ""
}

variable "enable_registry" {
  type    = bool
  default = true
}

variable "registry_hostname" {
  type    = string
  default = "registry.drksci.local"
}

variable "registry_storage_size" {
  type    = string
  default = "80Gi"
}

variable "registry_retention_days" {
  type    = number
  default = 30
}

variable "enable_dashboard" {
  type    = bool
  default = true
}

variable "enable_dockge" {
  type    = bool
  default = true
}

variable "enable_kite" {
  type    = bool
  default = true
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
  type    = string
  default = "/opt/stacks"
}

variable "dashboard_session_duration" {
  type    = string
  default = "30m"
}

variable "enable_argocd" {
  type    = bool
  default = true
}

variable "argocd_hostname" {
  type    = string
  default = "argocd.drksci.local"
}

variable "enable_homepage" {
  type    = bool
  default = true
}

variable "homepage_hostname" {
  type    = string
  default = "home.drksci.local"
}

variable "enable_storage" {
  type    = bool
  default = true
}

variable "enable_longhorn" {
  type    = bool
  default = true
}

variable "enable_minio" {
  type    = bool
  default = true
}

variable "minio_hostname" {
  type    = string
  default = "minio.drksci.local"
}

variable "minio_console_hostname" {
  type    = string
  default = "minio-console.drksci.local"
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
  type    = number
  default = 1
}

variable "enable_observability" {
  type    = bool
  default = true
}

variable "enable_pulse" {
  type    = bool
  default = true
}

variable "pulse_hostname" {
  type    = string
  default = "pulse.drksci.local"
}

variable "enable_polaris" {
  type    = bool
  default = true
}

variable "polaris_hostname" {
  type    = string
  default = "polaris.drksci.local"
}

variable "enable_backup" {
  type    = bool
  default = false
}

variable "enable_velero" {
  type    = bool
  default = true
}

variable "backup_schedule" {
  type    = string
  default = "0 3 * * *"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "enable_gdrive_sync" {
  type    = bool
  default = false
}

variable "gdrive_rclone_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "gdrive_folder_id" {
  type    = string
  default = ""
}

variable "cloudflare_api_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "cloudflare_account_id" {
  type    = string
  default = ""
}

variable "cloudflare_zone_id" {
  type    = string
  default = ""
}

variable "cloudflare_domain" {
  type    = string
  default = ""
}

variable "tailscale_auth_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "argocd_exposure" {
  type    = string
  default = "internal"
}

variable "kite_exposure" {
  type    = string
  default = "internal"
}

variable "homepage_exposure" {
  type    = string
  default = "internal"
}

variable "enable_github_runner" {
  type    = bool
  default = false
}

variable "github_url" {
  type    = string
  default = ""
}

variable "github_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "enable_gvisor" {
  type    = bool
  default = true
}

variable "enable_kata" {
  type    = bool
  default = false
}

variable "container_runtime_interface" {
  type    = string
  default = "containerd"
}

variable "enable_botkube" {
  type    = bool
  default = false
}

variable "botkube_webhook_url" {
  type    = string
  default = ""
}

variable "botkube_platform" {
  type    = string
  default = "discord"
}

variable "botkube_channel" {
  type    = string
  default = "homelab"
}
