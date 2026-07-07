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

variable "enable_pulse" {
  type    = bool
  default = true
}

variable "pulse_hostname" {
  type    = string
  default = "pulse.drksci.local"
}

variable "enable_polaris" {
  type    = bool
  default = true
}

variable "polaris_hostname" {
  type    = string
  default = "polaris.drksci.local"
}

variable "sablier_enabled" {
  type    = bool
  default = false
}

variable "sablier_session_duration" {
  type    = string
  default = "30m"
}
