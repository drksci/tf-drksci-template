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

variable "dagger_version" {
  description = "Dagger version tag (e.g. v0.13.3). Empty = latest."
  type        = string
  default     = ""
}

variable "docker_socket" {
  description = "Docker/container socket path on the remote host"
  type        = string
  default     = "/var/run/docker.sock"
}
