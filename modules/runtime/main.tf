# Each runtime gets its own null_resource gated by count so script paths
# are always statically known at plan time (avoids filemd5 dynamic path issues).

locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

# ---------------------------------------------------------------------------
# k3s — control-plane (server)
# ---------------------------------------------------------------------------
resource "null_resource" "k3s_server" {
  count = var.runtime == "k3s" && var.role == "server" ? 1 : 0

  triggers = {
    script_hash = filemd5("${path.module}/scripts/install-k3s-server.sh")
    host        = var.host
    k3s_release = var.k3s_release
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
    source      = "${path.module}/scripts/install-k3s-server.sh"
    destination = "/tmp/install-runtime.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-runtime.sh",
      "sudo K3S_RELEASE='${var.k3s_release}' K3S_TOKEN='${var.k3s_token}' CRI='${var.container_runtime_interface}' /tmp/install-runtime.sh",
    ]
  }
}

# ---------------------------------------------------------------------------
# k3s — worker (agent)
# ---------------------------------------------------------------------------
resource "null_resource" "k3s_agent" {
  count = var.runtime == "k3s" && var.role == "agent" ? 1 : 0

  triggers = {
    script_hash    = filemd5("${path.module}/scripts/install-k3s-agent.sh")
    host           = var.host
    k3s_release    = var.k3s_release
    k3s_server_url = var.k3s_server_url
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
    source      = "${path.module}/scripts/install-k3s-agent.sh"
    destination = "/tmp/install-runtime.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-runtime.sh",
      "sudo K3S_RELEASE='${var.k3s_release}' K3S_TOKEN='${var.k3s_token}' K3S_URL='${var.k3s_server_url}' /tmp/install-runtime.sh",
    ]
  }
}

# ---------------------------------------------------------------------------
# Colima (macOS)
# ---------------------------------------------------------------------------
resource "null_resource" "colima" {
  count = var.runtime == "colima" ? 1 : 0

  triggers = {
    script_hash = filemd5("${path.module}/scripts/install-colima.sh")
    host        = var.host
    k8s_version = var.k8s_version
    cpu         = var.cpu
    memory_gb   = var.memory_gb
    disk_gb     = var.disk_gb
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
    source      = "${path.module}/scripts/install-colima.sh"
    destination = "/tmp/install-runtime.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-runtime.sh",
      "CPU='${var.cpu}' MEMORY_GB='${var.memory_gb}' DISK_GB='${var.disk_gb}' K8S_VERSION='${var.k8s_version}' /tmp/install-runtime.sh",
    ]
  }
}

# ---------------------------------------------------------------------------
# Podman (Linux) — installs Podman + k3s (containerd) side-by-side
# ---------------------------------------------------------------------------
resource "null_resource" "podman" {
  count = var.runtime == "podman" && var.role == "server" ? 1 : 0

  triggers = {
    script_hash = filemd5("${path.module}/scripts/install-podman.sh")
    host        = var.host
    k3s_release = var.k3s_release
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
    source      = "${path.module}/scripts/install-podman.sh"
    destination = "/tmp/install-runtime.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-runtime.sh",
      "sudo K3S_RELEASE='${var.k3s_release}' K3S_TOKEN='${var.k3s_token}' /tmp/install-runtime.sh",
    ]
  }
}

# ---------------------------------------------------------------------------
# Minikube
# ---------------------------------------------------------------------------
resource "null_resource" "minikube" {
  count = var.runtime == "minikube" ? 1 : 0

  triggers = {
    script_hash = filemd5("${path.module}/scripts/install-minikube.sh")
    host        = var.host
    k8s_version = var.k8s_version
    cpu         = var.cpu
    memory_gb   = var.memory_gb
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
    source      = "${path.module}/scripts/install-minikube.sh"
    destination = "/tmp/install-runtime.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-runtime.sh",
      "CPU='${var.cpu}' MEMORY_GB='${var.memory_gb}' K8S_VERSION='${var.k8s_version}' /tmp/install-runtime.sh",
    ]
  }
}

# ---------------------------------------------------------------------------
# Colima — worker node (macOS → joins existing k3s cluster via Colima VM)
# ---------------------------------------------------------------------------
resource "null_resource" "colima_worker" {
  count = var.runtime == "colima" && var.role == "agent" ? 1 : 0

  triggers = {
    script_hash    = filemd5("${path.module}/scripts/install-colima-worker.sh")
    host           = var.host
    k3s_server_url = var.k3s_server_url
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
    source      = "${path.module}/scripts/install-colima-worker.sh"
    destination = "/tmp/install-runtime.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-runtime.sh",
      "K3S_URL='${var.k3s_server_url}' K3S_TOKEN='${var.k3s_token}' K3S_RELEASE='${var.k3s_release}' /tmp/install-runtime.sh",
    ]
  }
}

# ---------------------------------------------------------------------------
# MicroK8s (Ubuntu/Snap)
# ---------------------------------------------------------------------------
resource "null_resource" "microk8s_server" {
  count = var.runtime == "microk8s" && var.role == "server" ? 1 : 0

  triggers = {
    script_hash = filemd5("${path.module}/scripts/install-microk8s-server.sh")
    host        = var.host
    channel     = var.microk8s_channel
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
    source      = "${path.module}/scripts/install-microk8s-server.sh"
    destination = "/tmp/install-runtime.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-runtime.sh",
      "sudo MICROK8S_CHANNEL='${var.microk8s_channel}' /tmp/install-runtime.sh",
    ]
  }
}

resource "null_resource" "microk8s_agent" {
  count = var.runtime == "microk8s" && var.role == "agent" ? 1 : 0

  triggers = {
    script_hash    = filemd5("${path.module}/scripts/install-microk8s-agent.sh")
    host           = var.host
    k3s_server_url = var.k3s_server_url # reuse: microk8s join url
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
    source      = "${path.module}/scripts/install-microk8s-agent.sh"
    destination = "/tmp/install-runtime.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-runtime.sh",
      "sudo MICROK8S_CHANNEL='${var.microk8s_channel}' JOIN_URL='${var.k3s_server_url}' /tmp/install-runtime.sh",
    ]
  }
}
