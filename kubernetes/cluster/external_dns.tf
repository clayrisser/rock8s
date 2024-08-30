module "external-dns" {
  source  = "./modules/external_dns"
  enabled = var.external_dns
  target  = var.cluster_entrypoint
  dns_providers = {
    pdns = {
      api_url = var.pdns_api_url
      api_key = var.pdns_api_key
    }
  }
}
