locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "docuum" {
  triggers = {
    script_hash   = filemd5("${path.module}/scripts/install-docuum.sh")
    host          = var.host
    threshold     = var.threshold
    docker_socket = var.docker_socket
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
    source      = "${path.module}/scripts/install-docuum.sh"
    destination = "/tmp/install-docuum.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-docuum.sh",
      var.os == "macos" ? "THRESHOLD='${var.threshold}' DOCKER_SOCKET='${var.docker_socket}' /tmp/install-docuum.sh" : "sudo THRESHOLD='${var.threshold}' DOCKER_SOCKET='${var.docker_socket}' /tmp/install-docuum.sh",
    ]
  }
}
