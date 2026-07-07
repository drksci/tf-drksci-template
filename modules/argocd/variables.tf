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

variable "argocd_hostname" {
  type    = string
  default = "argocd.homelab.local"
}

variable "argocd_version" {
  description = "Helm chart version — empty string means latest"
  type        = string
  default     = ""
}

variable "sablier_enabled" {
  type    = bool
  default = false
}

variable "sablier_session_duration" {
  type    = string
  default = "30m"
}
