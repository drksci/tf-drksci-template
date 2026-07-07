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

variable "enable_dockge" {
  description = "Deploy Dockge — Docker Compose stack manager (host container)"
  type        = bool
  default     = true
}

variable "enable_kite" {
  description = "Deploy Kite — multi-cluster k8s dashboard with OAuth, Helm UI, Prometheus, AI"
  type        = bool
  default     = true
}

variable "dockge_hostname" {
  type    = string
  default = "dockge.homelab.local"
}

variable "kite_hostname" {
  type    = string
  default = "kite.homelab.local"
}

variable "dockge_stacks_dir" {
  description = "Host path where Dockge stores Docker Compose stacks"
  type        = string
  default     = "/opt/stacks"
}

variable "sablier_enabled" {
  type    = bool
  default = true
}

variable "sablier_session_duration" {
  type    = string
  default = "30m"
}
