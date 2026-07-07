# Cloudflare resources — only active when cloudflare_api_token + account_id + domain are set.
# Creates a named tunnel and a DNS CNAME for each service marked exposure = "public".

resource "random_password" "cf_tunnel_secret" {
  count   = local.cf_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  count      = local.cf_enabled ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "homelab"
  secret     = base64encode(random_password.cf_tunnel_secret[0].result)
}

# One CNAME per public service → tunnel.cfargotunnel.com (proxied through Cloudflare)
# nonsensitive() is required because local.public_services is tainted by cf_enabled,
# which is derived from the sensitive cloudflare_api_token variable. The keys
# (service slugs / public hostnames) are not themselves sensitive.
resource "cloudflare_record" "public_services" {
  for_each = nonsensitive(local.public_services)
  zone_id  = var.cloudflare_zone_id
  name     = split(".", each.value.public_hostname)[0]
  type     = "CNAME"
  value    = "${cloudflare_zero_trust_tunnel_cloudflared.homelab[0].id}.cfargotunnel.com"
  proxied  = true
  ttl      = 1
}
