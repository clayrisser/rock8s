// TODO: add buckets

module "rancher-logging" {
  source             = "./modules/rancher_logging"
  enabled            = local.rancher_logging
  rancher_cluster_id = local.rancher_cluster_id
  rancher_project_id = local.rancher_project_id
  bucket             = ""
  endpoint           = ""
  region             = "us-east-1"
  access_key         = ""
  secret_key         = ""
  grafana_repo       = try(rancher2_catalog_v2.grafana[0].name, "")
  retention          = "720h"
  depends_on = [
    kubernetes_namespace.rancher_monitoring
  ]
}
