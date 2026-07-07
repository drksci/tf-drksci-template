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

variable "notification_platform" {
  description = "Chat platform to deliver alerts: discord, slack, or mattermost"
  type        = string
  default     = "discord"
  validation {
    condition     = contains(["discord", "slack", "mattermost"], var.notification_platform)
    error_message = "notification_platform must be discord, slack, or mattermost."
  }
}

variable "webhook_url" {
  description = "Incoming webhook URL for your Discord/Slack/Mattermost channel"
  type        = string
  sensitive   = true
}

variable "channel_name" {
  description = "Channel name to post alerts to (e.g. #homelab-alerts)"
  type        = string
  default     = "homelab-alerts"
}

variable "cluster_name" {
  description = "Cluster display name in BotKube messages"
  type        = string
  default     = "homelab"
}

variable "enable_kubectl_executor" {
  description = "Allow running kubectl commands from the chat interface"
  type        = bool
  default     = true
}

variable "enable_helm_executor" {
  description = "Allow running helm commands from the chat interface"
  type        = bool
  default     = false
}
