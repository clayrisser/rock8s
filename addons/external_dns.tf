module "external-dns" {
  source  = "./modules/external_dns"
  enabled = local.external_dns
  default_targets = [
    local.entrypoint
  ]
  dns_providers = {
    pdns = {
      api_url = try(var.external_dns.powerdns.api_url, "")
      api_key = try(var.external_dns.powerdns.api_key, "")
    }
    hetzner = {
      api_key = try(var.external_dns.hetzner.api_key, "")
    }
    cloudflare = {
      api_key = try(var.external_dns.cloudflare.api_key, "")
      email   = try(var.external_dns.cloudflare.email, "")
    }
  }
}
