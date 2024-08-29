module "longhorn" {
  source             = "./modules/longhorn"
  enabled            = local.longhorn
  rancher_cluster_id = local.rancher_cluster_id
  rancher_project_id = local.rancher_project_id
  depends_on = [
    module.rancher
  ]
}
