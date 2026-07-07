locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "botkube" {
  triggers = {
    script_hash  = filemd5("${path.module}/scripts/install-botkube.sh")
    host         = var.host
    platform     = var.notification_platform
    cluster_name = var.cluster_name
    channel      = var.channel_name
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
    source      = "${path.module}/scripts/install-botkube.sh"
    destination = "/tmp/install-botkube.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-botkube.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "PLATFORM='${var.notification_platform}'",
        "WEBHOOK_URL='${var.webhook_url}'",
        "CHANNEL='${var.channel_name}'",
        "CLUSTER_NAME='${var.cluster_name}'",
        "ENABLE_KUBECTL='${var.enable_kubectl_executor}'",
        "ENABLE_HELM='${var.enable_helm_executor}'",
        var.os == "macos" ? "/tmp/install-botkube.sh" : "sudo -E /tmp/install-botkube.sh",
      ]),
    ]
  }
}
