locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "argocd" {
  triggers = {
    script_hash     = filemd5("${path.module}/scripts/install-argocd.sh")
    host            = var.host
    argocd_hostname = var.argocd_hostname
    argocd_version  = var.argocd_version
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
    source      = "${path.module}/scripts/install-argocd.sh"
    destination = "/tmp/install-argocd.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-argocd.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "ARGOCD_HOSTNAME='${var.argocd_hostname}'",
        "ARGOCD_VERSION='${var.argocd_version}'",
        "SABLIER_ENABLED='${var.sablier_enabled}'",
        "SABLIER_SESSION_DURATION='${var.sablier_session_duration}'",
        var.os == "macos" ? "/tmp/install-argocd.sh" : "sudo -E /tmp/install-argocd.sh",
      ]),
    ]
  }
}
