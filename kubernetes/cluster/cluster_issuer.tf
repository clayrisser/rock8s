module "cluster-issuer" {
  source            = "./modules/cluster_issuer"
  enabled           = var.cluster_issuer
  letsencrypt_email = var.email
  issuers = {
    letsencrypt = true
    selfsigned  = true
    route53 = {
      region = var.region
    }
  }
  depends_on = [
    null_resource.wait-for-ingress-nginx
  ]
}
