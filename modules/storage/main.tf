locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

# ---------------------------------------------------------------------------
# Longhorn — distributed block storage (deploy first: registry + MinIO use it)
# ---------------------------------------------------------------------------

resource "null_resource" "longhorn" {
  count = var.enable_longhorn ? 1 : 0

  triggers = {
    script_hash   = filemd5("${path.module}/scripts/install-longhorn.sh")
    host          = var.host
    replica_count = var.longhorn_replica_count
    longhorn_host = var.longhorn_hostname
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
    source      = "${path.module}/scripts/install-longhorn.sh"
    destination = "/tmp/install-longhorn.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-longhorn.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "LONGHORN_HOST='${var.longhorn_hostname}'",
        "REPLICA_COUNT='${var.longhorn_replica_count}'",
        "DATA_PATH='${var.longhorn_data_path}'",
        var.os == "macos" ? "/tmp/install-longhorn.sh" : "sudo -E /tmp/install-longhorn.sh",
      ]),
    ]
  }
}

# ---------------------------------------------------------------------------
# MinIO — S3-compatible object storage
# ---------------------------------------------------------------------------

resource "null_resource" "minio" {
  count      = var.enable_minio ? 1 : 0
  depends_on = [null_resource.longhorn]

  triggers = {
    script_hash  = filemd5("${path.module}/scripts/install-minio.sh")
    host         = var.host
    minio_host   = var.minio_hostname
    console_host = var.minio_console_hostname
    storage_size = var.minio_storage_size
    root_user    = var.minio_root_user
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
    source      = "${path.module}/scripts/install-minio.sh"
    destination = "/tmp/install-minio.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-minio.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "MINIO_HOST='${var.minio_hostname}'",
        "CONSOLE_HOST='${var.minio_console_hostname}'",
        "ROOT_USER='${var.minio_root_user}'",
        "ROOT_PASSWORD='${var.minio_root_password}'",
        "MINIO_DATA_PATH='${var.minio_data_path}'",
        "STACKS_DIR='${var.dockge_stacks_dir}'",
        var.os == "macos" ? "/tmp/install-minio.sh" : "sudo -E /tmp/install-minio.sh",
      ]),
    ]
  }
}

output "minio_s3_url" { value = var.enable_minio ? "http://${var.minio_hostname}" : "" }
output "minio_console_url" { value = var.enable_minio ? "http://${var.minio_console_hostname}" : "" }
output "longhorn_url" { value = var.enable_longhorn ? "http://${var.longhorn_hostname}" : "" }
