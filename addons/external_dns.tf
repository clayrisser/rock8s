module "external-dns" {
  source  = "./modules/external_dns"
  enabled = local.external_dns
  default_targets = [
    local.entrypoint
  ]
  dns_providers = {
    cloudflare = {
      api_key = try(
        var.external_dns == true ? "" : var.external_dns.cloudflare.api_key,
        ""
      )
      email = try(
        var.external_dns == true ? "" : var.external_dns.cloudflare.email,
        ""
      )
    }
    hetzner = {
      api_key = try(
        var.external_dns == true ? "" : var.external_dns.hetzner.api_key,
        ""
      )
    }
    route53 = {
      region = try(
        var.external_dns == true ? "" : var.external_dns.route53.region,
        ""
      )
      access_key = try(
        var.external_dns == true ? "" : var.external_dns.route53.access_key,
        ""
      )
      secret_key = try(
        var.external_dns == true ? "" : var.external_dns.route53.secret_key,
        ""
      )
      role_arn = try(
        var.external_dns == true ? "" : var.external_dns.route53.role_arn,
        ""
      )
    }
    digitalocean = {
      api_token = try(
        var.external_dns == true ? "" : var.external_dns.digitalocean.api_token,
        ""
      )
    }
    pdns = {
      api_url = try(
        var.external_dns == true ? "" : var.external_dns.powerdns.api_url,
        ""
      )
      api_key = try(
        var.external_dns == true ? "" : var.external_dns.powerdns.api_key,
        ""
      )
    }
  }
}
