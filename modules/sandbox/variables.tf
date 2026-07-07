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

variable "enable_gvisor" {
  description = <<-EOT
    Install gVisor (runsc) — Google's syscall-intercepting sandbox.
    Lighter than Kata (no VM), strong isolation for untrusted workloads.
    RuntimeClass: gvisor. Use: runtimeClassName: gvisor in pod spec.
    Requires Linux x86-64; not supported on macOS runtimes.
  EOT
  type        = bool
  default     = true
}

variable "enable_kata" {
  description = <<-EOT
    Install Kata Containers — VM-per-pod hardware isolation via QEMU/cloud-hypervisor.
    Strongest isolation (true VM boundary); higher overhead than gVisor.
    RuntimeClass: kata. Use: runtimeClassName: kata in pod spec.
    Requires hardware virtualisation (KVM); check: egrep -c '(vmx|svm)' /proc/cpuinfo
  EOT
  type        = bool
  default     = false
}

variable "kata_hypervisor" {
  description = "Kata hypervisor: qemu, cloud-hypervisor, or dragonball"
  type        = string
  default     = "qemu"
  validation {
    condition     = contains(["qemu", "cloud-hypervisor", "dragonball"], var.kata_hypervisor)
    error_message = "kata_hypervisor must be qemu, cloud-hypervisor, or dragonball."
  }
}
