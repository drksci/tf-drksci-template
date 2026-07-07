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

variable "cf_tunnel_token" {
  type      = string
  default   = ""
  sensitive = true
}
variable "tailscale_auth_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "public_services_json" {
  type    = string
  default = "{}"
}
variable "tailnet_services_json" {
  type    = string
  default = "{}"
}
variable "cloudflare_domain" {
  type    = string
  default = ""
}
