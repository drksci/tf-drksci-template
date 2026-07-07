locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "sablier" {
  triggers = {
    script_hash      = filemd5("${path.module}/scripts/install-sablier.sh")
    host             = var.host
    session_duration = var.session_duration
    sablier_version  = var.sablier_version
    traefik_version  = var.traefik_version
    traefik_lb_ip    = var.traefik_lb_ip
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
    source      = "${path.module}/scripts/install-sablier.sh"
    destination = "/tmp/install-sablier.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-sablier.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "SESSION_DURATION='${var.session_duration}'",
        "SABLIER_VERSION='${var.sablier_version}'",
        "TRAEFIK_VERSION='${var.traefik_version}'",
        "TRAEFIK_LB_IP='${var.traefik_lb_ip}'",
        var.os == "macos" ? "/tmp/install-sablier.sh" : "sudo -E /tmp/install-sablier.sh",
      ]),
    ]
  }
}
