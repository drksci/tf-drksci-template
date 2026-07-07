locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "github_runner" {
  triggers = {
    script_hash     = filemd5("${path.module}/scripts/install-github-runner.sh")
    host            = var.host
    github_url      = var.github_url
    runner_replicas = var.runner_replicas
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
    source      = "${path.module}/scripts/install-github-runner.sh"
    destination = "/tmp/install-github-runner.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-github-runner.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "GITHUB_URL='${var.github_url}'",
        "GITHUB_TOKEN='${var.github_token}'",
        "GITHUB_APP_ID='${var.github_app_id}'",
        "GITHUB_APP_INSTALLATION_ID='${var.github_app_installation_id}'",
        "GITHUB_APP_PRIVATE_KEY='${var.github_app_private_key}'",
        "RUNNER_REPLICAS='${var.runner_replicas}'",
        var.os == "macos" ? "/tmp/install-github-runner.sh" : "sudo -E /tmp/install-github-runner.sh",
      ]),
    ]
  }
}
