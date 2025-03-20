// TODO: add buckets

module "tempo" {
  source             = "./modules/tempo"
  enabled            = local.tempo
  rancher_cluster_id = local.rancher_cluster_id
  rancher_project_id = local.rancher_project_id
  bucket             = ""
  endpoint           = "s3.us-east-1.amazonaws.com"
  access_key         = ""
  secret_key         = ""
  grafana_repo       = ""
  retention          = "${length(try(var.tempo.retention_hours, "")) > 0 ? try(var.tempo.retention_hours, "720") : "720"}h"
  depends_on = [
    kubernetes_namespace.rancher_monitoring
  ]
}
