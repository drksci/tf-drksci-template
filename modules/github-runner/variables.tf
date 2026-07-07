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

variable "github_url" {
  description = "GitHub org or user URL, e.g. https://github.com/myorg"
  type        = string
}

variable "github_token" {
  description = "Classic PAT (repo + workflow scopes) — alternative to GitHub App"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_id" {
  type    = string
  default = ""
}
variable "github_app_installation_id" {
  type    = string
  default = ""
}
variable "github_app_private_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "runner_replicas" {
  description = "Number of concurrent runner pods"
  type        = number
  default     = 2
}
