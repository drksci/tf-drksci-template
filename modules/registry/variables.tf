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
  description = "Path to kubeconfig on the remote host"
  type        = string
  default     = "/etc/rancher/k3s/k3s.yaml"
}

variable "registry_storage_size" {
  description = "PVC size for registry image storage"
  type        = string
  default     = "50Gi"
}

variable "registry_hostname" {
  description = "Hostname for the registry ingress (e.g. registry.drksci.local)"
  type        = string
  default     = "registry.drksci.local"
}

variable "retention_enabled" {
  description = "Enable registry garbage collection (image retention)"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Days to keep untagged image manifests before GC"
  type        = number
  default     = 30
}
