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

variable "runtime" {
  description = "Active runtime (used to determine KUBECONFIG env)"
  type        = string
  default     = "k3s"
}

variable "sablier_version" {
  description = "Sablier Helm chart version. Empty = latest from repo."
  type        = string
  default     = ""
}

variable "traefik_version" {
  description = "Traefik Helm chart version. Empty = latest from repo."
  type        = string
  default     = ""
}

variable "session_duration" {
  description = "Sablier idle timeout before scaling to zero"
  type        = string
  default     = "10m"
}

variable "traefik_lb_ip" {
  description = "Optional static LoadBalancer IP for Traefik"
  type        = string
  default     = ""
}
