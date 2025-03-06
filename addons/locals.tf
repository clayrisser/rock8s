locals {
  entrypoint         = var.entrypoint != "" ? var.entrypoint : local.load_balancer
  ingress_ports      = [for port in split(",", var.ingress_ports) : port]
  kanister           = var.kanister && var.flux && var.olm
  kubeconfig         = jsonencode(local.kubeconfig_json)
  kubeconfig_json    = yamldecode(file(var.kubeconfig))
  load_balancer      = var.ingress_nginx ? data.kubernetes_service.ingress_nginx[0].status[0].load_balancer[0].ingress[0].ip : null
  rancher            = var.rancher && var.ingress_nginx && var.kyverno
  rancher_cluster_id = var.rancher ? "local" : ""
  rancher_istio      = var.rancher_istio && var.rancher_monitoring && local.rancher
  rancher_logging    = var.rancher_logging && var.rancher_monitoring && local.rancher
  rancher_project_id = var.rancher ? module.rancher.system_project_id : ""
  tempo              = var.tempo && local.rancher_logging
}
