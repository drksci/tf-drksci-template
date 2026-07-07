locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

# ---------------------------------------------------------------------------
# Pulse — unified Docker + k8s real-time monitoring (server + host agent)
# ---------------------------------------------------------------------------

resource "null_resource" "pulse" {
  count = var.enable_pulse ? 1 : 0

  triggers = {
    script_hash    = filemd5("${path.module}/scripts/install-pulse.sh")
    host           = var.host
    pulse_hostname = var.pulse_hostname
  }

  connection {
    type        = "ssh"
    host        = var.host
    user        = var.user
    port        = var.port
    private_key = local.conn_key
    password    = local.conn_pwd
    timeout     = var.ssh_timeout
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-pulse.sh"
    destination = "/tmp/install-pulse.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-pulse.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "PULSE_HOSTNAME='${var.pulse_hostname}'",
        "SABLIER_ENABLED='${var.sablier_enabled}'",
        "SABLIER_SESSION_DURATION='${var.sablier_session_duration}'",
        var.os == "macos" ? "/tmp/install-pulse.sh" : "sudo -E /tmp/install-pulse.sh",
      ]),
    ]
  }
}

# ---------------------------------------------------------------------------
# Polaris — Kubernetes best-practices validation dashboard + admission webhook
# ---------------------------------------------------------------------------

resource "null_resource" "polaris" {
  count = var.enable_polaris ? 1 : 0

  triggers = {
    script_hash      = filemd5("${path.module}/scripts/install-polaris.sh")
    host             = var.host
    polaris_hostname = var.polaris_hostname
  }

  connection {
    type        = "ssh"
    host        = var.host
    user        = var.user
    port        = var.port
    private_key = local.conn_key
    password    = local.conn_pwd
    timeout     = var.ssh_timeout
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-polaris.sh"
    destination = "/tmp/install-polaris.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-polaris.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "POLARIS_HOSTNAME='${var.polaris_hostname}'",
        "SABLIER_ENABLED='${var.sablier_enabled}'",
        "SABLIER_SESSION_DURATION='${var.sablier_session_duration}'",
        var.os == "macos" ? "/tmp/install-polaris.sh" : "sudo -E /tmp/install-polaris.sh",
      ]),
    ]
  }
}
