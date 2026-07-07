locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "registry" {
  triggers = {
    script_hash    = filemd5("${path.module}/scripts/install-registry.sh")
    host           = var.host
    storage_size   = var.registry_storage_size
    hostname       = var.registry_hostname
    retention_days = var.retention_days
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
    source      = "${path.module}/scripts/install-registry.sh"
    destination = "/tmp/install-registry.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-registry.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "STORAGE_SIZE='${var.registry_storage_size}'",
        "REGISTRY_HOST='${var.registry_hostname}'",
        "RETENTION_DAYS='${var.retention_days}'",
        var.os == "macos" ? "/tmp/install-registry.sh" : "sudo -E /tmp/install-registry.sh",
      ]),
    ]
  }
}

output "registry_url" {
  value = "http://${var.registry_hostname}"
}

output "push_instructions" {
  value = join("\n", [
    "Tag images as: ${var.registry_hostname}/<image>:<tag>",
    "Push with:     docker push ${var.registry_hostname}/<image>:<tag>",
    "In Dagger:     dag.Container().From(\"${var.registry_hostname}/<image>:<tag>\")",
    "Local resolve: add '127.0.0.1 ${var.registry_hostname}' to /etc/hosts (or use split-horizon DNS)",
  ])
}
