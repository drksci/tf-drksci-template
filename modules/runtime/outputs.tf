output "k3s_token" {
  description = "k3s join token (pass-through — managed by root random_password)"
  value       = var.k3s_token
  sensitive   = true
}

output "runtime" {
  value = var.runtime
}
