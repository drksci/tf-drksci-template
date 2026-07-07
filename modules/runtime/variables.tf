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

variable "runtime" {
  type    = string
  default = "k3s"
}

variable "role" {
  description = "server (control-plane) or agent (worker) — only used for k3s/microk8s"
  type        = string
  default     = "server"
}

variable "k3s_release" {
  description = "Full k3s release tag e.g. v1.30.5+k3s1"
  type        = string
  default     = "v1.30.5+k3s1"
}

variable "k8s_version" {
  description = "Kubernetes version (used by colima/minikube/microk8s)"
  type        = string
  default     = "v1.30.5"
}

variable "k3s_server_url" {
  description = "k3s API URL for worker join (e.g. https://192.168.1.10:6443)"
  type        = string
  default     = ""
}

variable "k3s_token" {
  description = "k3s cluster join token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cpu" {
  type    = number
  default = 4
}
variable "memory_gb" {
  type    = number
  default = 8
}
variable "disk_gb" {
  type    = number
  default = 60
}

variable "microk8s_channel" {
  description = "MicroK8s snap channel (e.g. 1.30/stable)"
  type        = string
  default     = "1.30/stable"
}

variable "container_runtime_interface" {
  description = <<-EOT
    Low-level CRI used by k3s/kubeadm. Only relevant when runtime = "k3s" or "kubeadm".
      containerd  — default for k3s (bundled), production-grade, CNCF graduated
      crio        — CRI-O: OCI-focused, no daemon, used by OpenShift/Fedora
    colima/minikube/microk8s manage their own CRI internally and ignore this.
  EOT
  type        = string
  default     = "containerd"

  validation {
    condition     = contains(["containerd", "crio"], var.container_runtime_interface)
    error_message = "container_runtime_interface must be containerd or crio."
  }
}
