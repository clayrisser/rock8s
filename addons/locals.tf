locals {
  entrypoint         = var.entrypoint != "" ? var.entrypoint : local.load_balancer
  ingress_ports      = [for port in var.ingress_ports : port]
  kanister           = var.kanister != null && var.flux != null && var.olm != null
  kubeconfig         = jsonencode(local.kubeconfig_json)
  kubeconfig_json    = yamldecode(file(var.kubeconfig))
  load_balancer      = var.ingress_nginx != null ? try(data.kubernetes_service.ingress_nginx[0].status[0].load_balancer[0].ingress[0].ip, null) : null
  rancher_istio      = var.rancher_istio != null && var.rancher_monitoring != null && local.rancher
  rancher_logging    = var.rancher_logging != null && var.rancher_monitoring != null && local.rancher
  tempo              = var.tempo != null && local.rancher_logging
  email              = var.email != "" ? var.email : try(var.external_dns.cloudflare.email, "")
  s3                 = var.s3 != null && var.integration_operator != null
  external_dns       = var.external_dns != null && var.kyverno != null
  rancher            = var.rancher != null && var.ingress_nginx != null && var.kyverno != null
  rancher_cluster_id = try(var.rancher.cluster_id, "local")
  rancher_project_id = try(module.rancher.system_project_id, "")
  git = {
    repo     = try(var.argocd.git.repo, "")
    username = try(var.argocd.git.username, "") != "" ? try(var.argocd.git.username, "") : (can(regex("gitlab.com", try(var.argocd.git.repo, ""))) && contains(keys(var.registries), "registry.gitlab.com") ? try(var.registries["registry.gitlab.com"].username, "") : "")
    password = try(var.argocd.git.password, "") != "" ? try(var.argocd.git.password, "") : (can(regex("gitlab.com", try(var.argocd.git.repo, ""))) && contains(keys(var.registries), "registry.gitlab.com") ? try(var.registries["registry.gitlab.com"].password, "") : "")
  }
}
