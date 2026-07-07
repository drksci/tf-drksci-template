locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
  enabled  = var.cf_tunnel_token != "" || var.tailscale_auth_key != ""
}

resource "null_resource" "exposure" {
  count = local.enabled ? 1 : 0

  triggers = {
    script_hash           = filemd5("${path.module}/scripts/install-exposure.sh")
    host                  = var.host
    public_services_hash  = md5(var.public_services_json)
    tailnet_services_hash = md5(var.tailnet_services_json)
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
    source      = "${path.module}/scripts/install-exposure.sh"
    destination = "/tmp/install-exposure.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-exposure.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "CF_TUNNEL_TOKEN='${var.cf_tunnel_token}'",
        "TAILSCALE_AUTH_KEY='${var.tailscale_auth_key}'",
        "PUBLIC_SERVICES_JSON='${var.public_services_json}'",
        "TAILNET_SERVICES_JSON='${var.tailnet_services_json}'",
        "CLOUDFLARE_DOMAIN='${var.cloudflare_domain}'",
        var.os == "macos" ? "/tmp/install-exposure.sh" : "sudo -E /tmp/install-exposure.sh",
      ]),
    ]
  }
}
