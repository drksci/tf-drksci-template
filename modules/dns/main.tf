locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
  enabled  = var.traefik_lb_ip != ""
}

resource "null_resource" "dns" {
  count = local.enabled ? 1 : 0

  triggers = {
    script_hash  = filemd5("${path.module}/scripts/install-dns.sh")
    host         = var.host
    traefik_ip   = var.traefik_lb_ip
    domain       = var.domain
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
    source      = "${path.module}/scripts/install-dns.sh"
    destination = "/tmp/install-dns.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-dns.sh",
      join(" ", [
        "TRAEFIK_IP='${var.traefik_lb_ip}'",
        "DOMAIN='${var.domain}'",
        "STACKS_DIR='${var.stacks_dir}'",
        "DNS_PORT='${var.dns_port}'",
        var.os == "macos" ? "/tmp/install-dns.sh" : "sudo -E /tmp/install-dns.sh",
      ]),
    ]
  }
}
