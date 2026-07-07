locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "homepage" {
  triggers = {
    script_hash       = filemd5("${path.module}/scripts/install-homepage.sh")
    host              = var.host
    homepage_hostname = var.homepage_hostname
    minio_hostname    = var.minio_hostname
    longhorn_hostname = var.longhorn_hostname
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
    source      = "${path.module}/scripts/install-homepage.sh"
    destination = "/tmp/install-homepage.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-homepage.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "HOMEPAGE_HOSTNAME='${var.homepage_hostname}'",
        "CLUSTER_NAME='${var.cluster_name}'",
        "MINIO_HOSTNAME='${var.minio_hostname}'",
        "MINIO_CONSOLE_HOSTNAME='${var.minio_console_hostname}'",
        "MINIO_ACCESS_KEY='${var.minio_access_key}'",
        "MINIO_SECRET_KEY='${var.minio_secret_key}'",
        "LONGHORN_HOSTNAME='${var.longhorn_hostname}'",
        "KITE_HOSTNAME='${var.kite_hostname}'",
        "DOCKGE_HOSTNAME='${var.dockge_hostname}'",
        "PULSE_HOSTNAME='${var.pulse_hostname}'",
        "POLARIS_HOSTNAME='${var.polaris_hostname}'",
        "REGISTRY_HOSTNAME='${var.registry_hostname}'",
        var.os == "macos" ? "/tmp/install-homepage.sh" : "sudo -E /tmp/install-homepage.sh",
      ]),
    ]
  }
}
