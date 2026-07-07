locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

# ---------------------------------------------------------------------------
# gVisor (runsc)
# ---------------------------------------------------------------------------

resource "null_resource" "gvisor" {
  count = var.enable_gvisor ? 1 : 0

  triggers = {
    script_hash = filemd5("${path.module}/scripts/install-gvisor.sh")
    host        = var.host
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
    source      = "${path.module}/scripts/install-gvisor.sh"
    destination = "/tmp/install-gvisor.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-gvisor.sh",
      "sudo KUBECONFIG='${var.kubeconfig_path}' /tmp/install-gvisor.sh",
    ]
  }
}

# ---------------------------------------------------------------------------
# Kata Containers
# ---------------------------------------------------------------------------

resource "null_resource" "kata" {
  count = var.enable_kata ? 1 : 0

  triggers = {
    script_hash = filemd5("${path.module}/scripts/install-kata.sh")
    host        = var.host
    hypervisor  = var.kata_hypervisor
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
    source      = "${path.module}/scripts/install-kata.sh"
    destination = "/tmp/install-kata.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-kata.sh",
      "sudo HYPERVISOR='${var.kata_hypervisor}' KUBECONFIG='${var.kubeconfig_path}' /tmp/install-kata.sh",
    ]
  }
}
