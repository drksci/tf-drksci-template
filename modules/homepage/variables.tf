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

variable "homepage_hostname" {
  type    = string
  default = "home.homelab.local"
}
variable "cluster_name" {
  type    = string
  default = "homelab"
}

# Service hostnames — used for widget API calls and tile hrefs
variable "minio_hostname" {
  type    = string
  default = ""
}
variable "minio_console_hostname" {
  type    = string
  default = ""
}
variable "minio_access_key" {
  type    = string
  default = "admin"
}
variable "minio_secret_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "longhorn_hostname" {
  type    = string
  default = ""
}
variable "kite_hostname" {
  type    = string
  default = ""
}
variable "dockge_hostname" {
  type    = string
  default = ""
}
variable "pulse_hostname" {
  type    = string
  default = ""
}
variable "polaris_hostname" {
  type    = string
  default = ""
}
variable "registry_hostname" {
  type    = string
  default = ""
}
