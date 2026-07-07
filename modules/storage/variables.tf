variable "host" { type = string }
variable "user" { type = string }
variable "port" {
  type    = number
  default = 22
}
variable "private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
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
  default = "5m"
}
variable "kubeconfig_path" {
  type    = string
  default = "/etc/rancher/k3s/k3s.yaml"
}

# ---------------------------------------------------------------------------
# MinIO — S3-compatible object storage
# ---------------------------------------------------------------------------

variable "enable_minio" {
  description = "Deploy MinIO — S3-compatible object storage with web console"
  type        = bool
  default     = true
}

variable "minio_hostname" {
  description = "Hostname for MinIO S3 API endpoint"
  type        = string
  default     = "s3.drksci.local"
}

variable "minio_console_hostname" {
  description = "Hostname for MinIO web console"
  type        = string
  default     = "minio.drksci.local"
}

variable "minio_root_user" {
  description = "MinIO root (admin) username"
  type        = string
  default     = "admin"
}

variable "minio_root_password" {
  description = "MinIO root password (min 8 chars)"
  type        = string
  sensitive   = true
}

variable "minio_storage_size" {
  description = "PVC size for MinIO object data"
  type        = string
  default     = "100Gi"
}

# ---------------------------------------------------------------------------
# Longhorn — distributed block storage / PVC manager
# ---------------------------------------------------------------------------

variable "enable_longhorn" {
  description = "Deploy Longhorn — distributed block storage with volume management UI"
  type        = bool
  default     = true
}

variable "longhorn_hostname" {
  description = "Hostname for Longhorn dashboard"
  type        = string
  default     = "longhorn.drksci.local"
}

variable "longhorn_replica_count" {
  description = "Number of volume replicas (1 for single-node, 2-3 for multi-node HA)"
  type        = number
  default     = 1
}

variable "longhorn_data_path" {
  description = "Host path where Longhorn stores volume data"
  type        = string
  default     = "/var/lib/longhorn"
}
