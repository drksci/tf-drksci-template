locals {
  script = var.os == "macos" ? "${path.module}/scripts/bootstrap-macos.sh" : "${path.module}/scripts/bootstrap-linux.sh"
}

resource "null_resource" "bootstrap" {
  triggers = {
    script_hash = filemd5(local.script)
    host        = var.host
  }

  connection {
    type        = "ssh"
    host        = var.host
    user        = var.user
    port        = var.port
    private_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
    password    = var.password != "" ? var.password : null
    timeout     = var.ssh_timeout
  }

  provisioner "file" {
    source      = local.script
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      var.os == "macos" ? "/tmp/bootstrap.sh" : "sudo /tmp/bootstrap.sh",
    ]
  }
}
