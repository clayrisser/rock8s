resource "kubernetes_namespace" "rancher_monitoring" {
  count = var.rancher_monitoring ? 1 : 0
  metadata {
    name = "cattle-monitoring-system"
  }
}

module "rancher-monitoring" {
  source                  = "./modules/rancher_monitoring"
  enabled                 = var.rancher_monitoring
  create_namespace        = false
  namespace               = try(kubernetes_namespace.rancher_monitoring[0].metadata[0].name, "")
  endpoint                = "s3.${var.region}.amazonaws.com"
  retention               = "168h"  # 7 days
  retention_resolution_1h = "720h"  # 30 days
  retention_resolution_5m = "8766h" # 1 year
  retention_size          = "1GiB"
  depends_on = [
    module.rancher,
    module.rancher-logging,
    module.tempo
  ]
}
