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

variable "traefik_lb_ip" {
  description = "Traefik LoadBalancer IP — all *.domain entries resolve here"
  type        = string
}

variable "domain" {
  description = "Internal domain to serve (e.g. drksci.local)"
  type        = string
  default     = "drksci.local"
}

variable "stacks_dir" {
  description = "Dockge stacks directory"
  type        = string
  default     = "/opt/stacks"
}

variable "dns_port" {
  description = "Port to bind dnsmasq on (53 requires NET_ADMIN cap)"
  type        = number
  default     = 53
}
