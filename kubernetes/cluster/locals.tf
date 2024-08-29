locals {
  cluster_entrypoint = var.ingress_nginx ? "http://${data.kubernetes_service.ingress_nginx[0].status[0].load_balancer[0].ingress[0].ip}" : null
  rancher_cluster_id = var.rancher ? "local" : ""
  rancher_project_id = var.rancher ? module.rancher.system_project_id : ""
  ingress_ports      = [for port in split(",", var.ingress_ports) : port]
  kubeconfig_json    = yamldecode(file(var.kubeconfig))
  kubeconfig         = jsonencode(local.kubeconfig_json)
  kanister           = var.kanister && var.flux && var.olm
  rancher            = var.rancher && var.ingress_nginx && var.kyverno
  rancher_istio      = var.rancher_istio && var.rancher_monitoring && local.rancher
  rancher_logging    = var.rancher_logging && var.rancher_monitoring && local.rancher
  tempo              = var.tempo && local.rancher_logging
  longhorn           = var.longhorn && local.rancher
}
