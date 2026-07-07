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

# Cloudflare provider — only configured when cloudflare_api_token is set
provider "cloudflare" {
  api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : "placeholder"
}

# Tailscale provider — only configured when tailscale_api_key is set
provider "tailscale" {
  api_key = var.tailscale_api_key != "" ? var.tailscale_api_key : "placeholder"
  tailnet = var.tailscale_tailnet
}
