module "rancher-istio" {
  source             = "./modules/rancher_istio"
  enabled            = local.rancher_istio
  rancher_cluster_id = local.rancher_cluster_id
  rancher_project_id = local.rancher_project_id
  depends_on = [
    module.rancher-monitoring
  ]
}
