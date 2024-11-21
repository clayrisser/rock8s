module "external-dns" {
  source  = "./modules/external_dns"
  enabled = var.external_dns
  targets = var.cluster_entrypoint
  dns_providers = {
    # pdns = {
    #   api_url = var.pdns_api_url
    #   api_key = var.pdns_api_key
    # }
    # hetzner = {
    #   api_key = var.hetzner_api_key
    # }
    cloudflare = {
      api_key = var.cloudflare_api_key
      email   = var.cloudflare_email
    }
  }
}
