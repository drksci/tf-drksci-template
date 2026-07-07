variable "host" { type = string }
variable "user" { type = string }
variable "port" {
  type    = number
  default = 22
}
variable "private_key_path" {
  type    = string
  default = ""
}
variable "password" {
  type      = string
  default   = ""
  sensitive = true
}
variable "os" {
  type    = string
  default = "linux"
}
variable "ssh_timeout" {
  type    = string
  default = "90s"
}
variable "kubeconfig_path" { type = string }

variable "enable_velero" {
  type    = bool
  default = true
}
variable "minio_endpoint" {
  type    = string
  default = "http://minio.minio.svc.cluster.local:9000"
}
variable "minio_bucket" {
  type    = string
  default = "velero"
}
variable "minio_access_key" {
  type    = string
  default = "admin"
}
variable "minio_secret_key" {
  type      = string
  sensitive = true
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
variable "gdrive_sync_schedule" {
  type    = string
  default = "0 4 * * *"
}

variable "enable_retention_detector" {
  type    = bool
  default = true
}
variable "retention_check_schedule" {
  type    = string
  default = "0 8 * * *"
}
variable "retention_alert_webhook" {
  type    = string
  default = ""
} # Discord/Slack webhook
