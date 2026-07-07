locals {
  conn_key = var.private_key_path != "" ? file(pathexpand(var.private_key_path)) : null
  conn_pwd = var.password != "" ? var.password : null
}

resource "null_resource" "velero" {
  count = var.enable_velero ? 1 : 0

  triggers = {
    script_hash     = filemd5("${path.module}/scripts/install-velero.sh")
    host            = var.host
    backup_schedule = var.backup_schedule
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
    source      = "${path.module}/scripts/install-velero.sh"
    destination = "/tmp/install-velero.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-velero.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "MINIO_ENDPOINT='${var.minio_endpoint}'",
        "MINIO_BUCKET='${var.minio_bucket}'",
        "MINIO_ACCESS_KEY='${var.minio_access_key}'",
        "MINIO_SECRET_KEY='${var.minio_secret_key}'",
        "BACKUP_SCHEDULE='${var.backup_schedule}'",
        "RETENTION_DAYS='${var.backup_retention_days}'",
        var.os == "macos" ? "/tmp/install-velero.sh" : "sudo -E /tmp/install-velero.sh",
      ]),
    ]
  }
}

resource "null_resource" "retention_detector" {
  count      = var.enable_retention_detector ? 1 : 0
  depends_on = [null_resource.velero]

  triggers = {
    script_hash              = filemd5("${path.module}/scripts/install-retention-detector.sh")
    host                     = var.host
    retention_check_schedule = var.retention_check_schedule
    alert_webhook            = var.retention_alert_webhook
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
    source      = "${path.module}/scripts/install-retention-detector.sh"
    destination = "/tmp/install-retention-detector.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-retention-detector.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "CHECK_SCHEDULE='${var.retention_check_schedule}'",
        "ALERT_WEBHOOK_URL='${var.retention_alert_webhook}'",
        var.os == "macos" ? "/tmp/install-retention-detector.sh" : "sudo -E /tmp/install-retention-detector.sh",
      ]),
    ]
  }
}

resource "null_resource" "rclone_gdrive" {
  count      = var.enable_gdrive_sync && var.gdrive_rclone_token != "" ? 1 : 0
  depends_on = [null_resource.velero]

  triggers = {
    script_hash          = filemd5("${path.module}/scripts/install-rclone.sh")
    host                 = var.host
    gdrive_sync_schedule = var.gdrive_sync_schedule
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
    source      = "${path.module}/scripts/install-rclone.sh"
    destination = "/tmp/install-rclone.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-rclone.sh",
      join(" ", [
        "KUBECONFIG='${var.kubeconfig_path}'",
        "MINIO_ENDPOINT='${var.minio_endpoint}'",
        "MINIO_BUCKET='${var.minio_bucket}'",
        "MINIO_ACCESS_KEY='${var.minio_access_key}'",
        "MINIO_SECRET_KEY='${var.minio_secret_key}'",
        "GDRIVE_RCLONE_TOKEN='${var.gdrive_rclone_token}'",
        "GDRIVE_FOLDER_ID='${var.gdrive_folder_id}'",
        "GDRIVE_SYNC_SCHEDULE='${var.gdrive_sync_schedule}'",
        var.os == "macos" ? "/tmp/install-rclone.sh" : "sudo -E /tmp/install-rclone.sh",
      ]),
    ]
  }
}
