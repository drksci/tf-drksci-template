# Compatible with OpenTofu >= 1.6 and Terraform >= 1.6
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.17"
    }
  }
}

# Cloudflare provider — only configured when cloudflare_api_token is set.
# Placeholder token satisfies format validation (40 alphanumeric chars) but
# all CF resources are guarded by count = local.cf_enabled so it never fires.
provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : "00000000000000000000000000000000000000CF"
}

# Tailscale provider — only configured when tailscale_api_key + tailscale_tailnet are set.
# Resources are guarded by local.tailscale_acl_enabled so the provider is never
# invoked when disabled; the placeholder values satisfy schema validation only.
provider "tailscale" {
  api_key = var.tailscale_api_key != "" ? var.tailscale_api_key : "tskey-api-placeholder"
  tailnet = var.tailscale_tailnet != "" ? var.tailscale_tailnet : "placeholder.ts.net"
}
