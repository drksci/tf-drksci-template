locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

# ---------------------------------------------------------------------------
# Dockge — Docker Compose stack manager (host Docker container)
# ---------------------------------------------------------------------------

resource "null_resource" "dockge" {
  count = var.enable_dockge ? 1 : 0

  triggers = {
    script_hash      = filemd5("${path.module}/scripts/install-dockge.sh")
    host             = var.host
    dockge_hostname  = var.dockge_hostname
    stacks_dir       = var.dockge_stacks_dir
    sablier_enabled  = var.sablier_enabled
    session_duration = var.sablier_session_duration
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
    source      = "${path.module}/scripts/install-dockge.sh"
    destination = "/tmp/install-dockge.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-dockge.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "DOCKGE_HOST='${var.dockge_hostname}'",
        "STACKS_DIR='${var.dockge_stacks_dir}'",
        "SABLIER='${var.sablier_enabled}'",
        "SESSION_DURATION='${var.sablier_session_duration}'",
        var.os == "macos" ? "/tmp/install-dockge.sh" : "sudo -E /tmp/install-dockge.sh",
      ]),
    ]
  }
}

# ---------------------------------------------------------------------------
# Kite — multi-cluster Kubernetes dashboard (Helm, runs inside k8s)
# ---------------------------------------------------------------------------

resource "null_resource" "kite" {
  count = var.enable_kite ? 1 : 0

  triggers = {
    script_hash      = filemd5("${path.module}/scripts/install-kite.sh")
    host             = var.host
    kite_hostname    = var.kite_hostname
    sablier_enabled  = var.sablier_enabled
    session_duration = var.sablier_session_duration
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
    source      = "${path.module}/scripts/install-kite.sh"
    destination = "/tmp/install-kite.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-kite.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "KITE_HOST='${var.kite_hostname}'",
        "SABLIER='${var.sablier_enabled}'",
        "SESSION_DURATION='${var.sablier_session_duration}'",
        var.os == "macos" ? "/tmp/install-kite.sh" : "sudo -E /tmp/install-kite.sh",
      ]),
    ]
  }
}

output "dockge_url" { value = var.enable_dockge ? "http://${var.dockge_hostname}" : "" }
output "kite_url" { value = var.enable_kite ? "http://${var.kite_hostname}" : "" }
