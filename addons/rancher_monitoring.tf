resource "kubernetes_namespace_v1" "rancher_monitoring" {
  count = var.rancher_monitoring != null ? 1 : 0
  metadata {
    name = "cattle-monitoring-system"
  }
  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

module "rancher_monitoring" {
  source           = "./modules/rancher_monitoring"
  enabled          = var.rancher_monitoring != null
  create_namespace = false
  namespace        = try(kubernetes_namespace_v1.rancher_monitoring[0].metadata[0].name, "")
  retention        = "168h" # 7 days
  retention_size   = "1GiB"
  depends_on = [
    module.ceph,
    module.rancher,
    module.rancher_logging,
    module.tempo,
  ]
}
