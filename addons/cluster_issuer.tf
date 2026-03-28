module "cluster-issuer" {
  source            = "./modules/cluster_issuer"
  enabled           = var.cluster_issuer != null
  letsencrypt_email = local.email
  issuers = {
    letsencrypt = true
    selfsigned  = true
    cloudflare = {
      api_key = try(
        var.cluster_issuer == true ? "" : var.cluster_issuer.cloudflare.api_key,
        try(var.external_dns == true ? "" : var.external_dns.cloudflare.api_key, "")
      )
      email = try(
        var.cluster_issuer == true ? "" : var.cluster_issuer.cloudflare.email,
        try(var.external_dns == true ? "" : var.external_dns.cloudflare.email, "")
      )
    }
    hetzner = {
      api_key = try(
        var.cluster_issuer == true ? "" : var.cluster_issuer.hetzner.api_key,
        try(var.external_dns == true ? "" : var.external_dns.hetzner.api_key, "")
      )
    }
    route53 = {
      region = try(
        var.cluster_issuer == true ? "" : var.cluster_issuer.route53.region,
        try(var.external_dns == true ? "" : var.external_dns.route53.region, "")
      )
    }
    digitalocean = {
      api_token = try(
        var.cluster_issuer == true ? "" : var.cluster_issuer.digitalocean.api_token,
        try(var.external_dns == true ? "" : var.external_dns.digitalocean.api_token, "")
      )
    }
    pdns = {
      api_url = try(
        var.cluster_issuer == true ? "" : var.cluster_issuer.pdns.api_url,
        try(var.external_dns == true ? "" : var.external_dns.powerdns.api_url, "")
      )
      api_key = try(
        var.cluster_issuer == true ? "" : var.cluster_issuer.pdns.api_key,
        try(var.external_dns == true ? "" : var.external_dns.powerdns.api_key, "")
      )
    }
  }
  depends_on = [
    data.kubernetes_service_v1.traefik
  ]
}
