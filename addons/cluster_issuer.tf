module "cluster-issuer" {
  source            = "./modules/cluster_issuer"
  enabled           = var.cluster_issuer != null
  letsencrypt_email = local.email
  issuers = {
    letsencrypt = true
    selfsigned  = true
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
  depends_on = [
    null_resource.wait-for-ingress-nginx
  ]
}
