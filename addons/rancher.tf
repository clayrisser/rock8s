module "rancher" {
  source                 = "./modules/rancher"
  enabled                = local.rancher
  kubeconfig             = local.kubeconfig
  letsencrypt_email      = var.email
  rancher_admin_password = var.rancher_admin_password
  rancher_cluster_id     = local.rancher_cluster_id
  rancher_hostname       = var.rancher_hostname
  rancher_token          = var.rancher_token
}

provider "rancher2" {
  api_url   = try(module.rancher.api_url, null)
  token_key = var.rancher_token != "" ? var.rancher_token : try(module.rancher.token, "")
}

resource "rancher2_catalog_v2" "grafana" {
  count      = local.rancher ? 1 : 0
  cluster_id = local.rancher_cluster_id
  name       = "grafana"
  url        = "https://grafana.github.io/helm-charts"
  depends_on = [
    module.rancher
  ]
}

resource "rancher2_catalog_v2" "rock8s" {
  count      = local.rancher ? 1 : 0
  cluster_id = local.rancher_cluster_id
  name       = "rock8s"
  url        = "https://charts.rock8s.com"
  depends_on = [
    module.rancher
  ]
}
