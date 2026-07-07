output "pulse_url" {
  value = var.enable_pulse ? "http://${var.pulse_hostname}" : ""
}

output "polaris_url" {
  value = var.enable_polaris ? "http://${var.polaris_hostname}" : ""
}
