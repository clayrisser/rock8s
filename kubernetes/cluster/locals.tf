locals {
    cluster_name = "demo-k8s-0.local"
#   cluster_name         = "${var.cluster_prefix}-${tostring(var.iteration)}.${var.dns_zone}"
#   user_name            = "${var.cluster_prefix}.${var.dns_zone}"
#   cluster_entrypoint   = local.cluster_name
#   rancher_cluster_id   = var.rancher ? "local" : ""
#   rancher_project_id   = var.rancher ? module.rancher.system_project_id : ""
#   public_api_ports     = [for port in split(",", var.public_api_ports) : port]
#   public_nodes_ports   = [for port in split(",", var.public_nodes_ports) : port]
  ingress_ports        = [for port in split(",", var.ingress_ports) : port]
#   cluster_endpoint     = "https://api.${local.cluster_name}"
  kubeconfig_json = yamldecode(file(var.kubeconfig))
  kubeconfig = jsonencode(local.kubeconfig_json)
#   kanister           = var.kanister && var.flux && var.olm
#   longhorn           = var.longhorn && local.rancher
#   rancher            = var.rancher && var.ingress_nginx && var.kyverno
#   rancher_istio      = var.rancher_istio && local.rancher_monitoring
#   rancher_logging    = var.rancher_logging && local.rancher_monitoring
#   rancher_monitoring = var.rancher_monitoring && local.rancher
#   tempo              = var.tempo && local.rancher_logging
#   thanos             = local.rancher_monitoring && var.thanos
}
