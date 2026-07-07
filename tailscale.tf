# Tailscale ACL — guest/host network segmentation.
# host:  full access to all homelab services (your own devices)
# guest: isolated access to MinIO S3 only (share credentials separately)
#
# Apply: set tailscale_api_key + tailscale_tailnet in terraform.tfvars.
# Tags must be pre-created in Tailscale admin before first apply.

locals {
  # ACL management requires both api_key and tailnet; operator only needs auth_key
  tailscale_acl_enabled = var.tailscale_api_key != "" && var.tailscale_tailnet != ""

  # Services reachable by hosts (admin layer)
  host_services = [
    "minio.drksci.local:9000",
    "minio.drksci.local:9001",
    "longhorn.drksci.local:80",
    "argocd.drksci.local:80",
    "pulse.drksci.local:80",
    "polaris.drksci.local:80",
    "kite.drksci.local:80",
    "dockge.drksci.local:80",
    "registry.drksci.local:5000",
  ]

  # Services reachable by guests (S3 only — share access keys separately)
  guest_services = [
    "minio.drksci.local:9000",
  ]
}

resource "tailscale_acl" "homelab" {
  count = local.tailscale_acl_enabled ? 1 : 0

  acl = jsonencode({
    tagOwners = {
      "tag:homelab-host"  = ["autogroup:owner"]
      "tag:homelab-guest" = ["autogroup:owner"]
    }

    groups = {
      "group:homelab-hosts"  = ["tag:homelab-host"]
      "group:homelab-guests" = ["tag:homelab-guest"]
    }

    acls = [
      # Hosts: full access between all host-tagged devices + all homelab services
      {
        action = "accept"
        src    = ["group:homelab-hosts"]
        dst    = ["group:homelab-hosts:*", "tag:homelab-host:*"]
      },
      # Guests: S3 API only — no access to admin UIs or other hosts
      {
        action = "accept"
        src    = ["group:homelab-guests"]
        dst    = ["tag:homelab-host:9000"]
      },
      # All devices: internet access
      {
        action = "accept"
        src    = ["*"]
        dst    = ["autogroup:internet:*"]
      },
    ]

    # SSH: hosts can SSH to homelab nodes; guests cannot
    ssh = [
      {
        action = "accept"
        src    = ["group:homelab-hosts"]
        dst    = ["tag:homelab-host"]
        users  = ["autogroup:nonroot"]
      },
    ]
  })
}
