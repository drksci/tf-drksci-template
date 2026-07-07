locals {
  script   = var.os == "macos" ? "${path.module}/scripts/install-dagger-macos.sh" : "${path.module}/scripts/install-dagger-linux.sh"
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "dagger" {
  triggers = {
    script_hash    = filemd5(local.script)
    host           = var.host
    dagger_version = var.dagger_version
    docker_socket  = var.docker_socket
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
    source      = local.script
    destination = "/tmp/install-dagger.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-dagger.sh",
      var.os == "macos" ? "DAGGER_VERSION='${var.dagger_version}' DOCKER_SOCKET='${var.docker_socket}' /tmp/install-dagger.sh" : "sudo DAGGER_VERSION='${var.dagger_version}' DOCKER_SOCKET='${var.docker_socket}' /tmp/install-dagger.sh",
    ]
  }
}

output "version" {
  value = var.dagger_version != "" ? var.dagger_version : "latest"
}
