module "external-dns" {
  source  = "./modules/external_dns"
  enabled = var.external_dns
  dns_providers = {
    pdns = {
      apiUrl  = var.pdns_api_url
      apiPort = var.pdns_api_port
      apiKey  = var.pdns_api_key
    }
  }
}
