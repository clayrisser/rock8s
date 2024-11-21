module "cluster-issuer" {
  source            = "./modules/cluster_issuer"
  enabled           = var.cluster_issuer
  letsencrypt_email = var.email
  issuers = {
    letsencrypt = true
    selfsigned  = true
    # pdns = {
    #   api_url = var.pdns_api_url
    #   api_key = var.pdns_api_key
    # }
    # hetzner = {
    #   api_key = var.hetzner_api_key
    # }
    cloudflare = {
      api_key = var.cloudflare_api_key
    }
  }
  depends_on = [
    null_resource.wait-for-ingress-nginx
  ]
}
