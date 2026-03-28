locals {
  entrypoint         = var.entrypoint != "" ? var.entrypoint : local.load_balancer
  kubeconfig         = jsonencode(local.kubeconfig_json)
  kubeconfig_json    = yamldecode(file(var.kubeconfig))
  load_balancer      = try(data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].ip, null)
  rancher_istio      = var.rancher_istio != null && var.rancher_monitoring != null && local.rancher
  rancher_logging    = var.rancher_logging != null && var.rancher_monitoring != null && local.rancher
  tempo              = var.tempo != null && local.rancher_logging
  external_dns       = var.external_dns != null && var.kyverno != null
  rancher            = var.rancher != null && var.kyverno != null
  rancher_cluster_id = try(var.rancher.cluster_id, "local")
  rancher_project_id = try(module.rancher.system_project_id, "")
  email = (var.email != "" && var.email != null) ? var.email : try(
    var.external_dns.cloudflare.email,
    var.cluster_issuer.cloudflare.email,
    ""
  )
  git = {
    repo = try(var.argocd.git.repo, "")
    username = try(coalesce(var.argocd.git.username, ""), "") != "" ? var.argocd.git.username : (
      (can(regex("gitlab.com", try(var.argocd.git.repo, ""))) &&
      contains(keys(var.registries), "registry.gitlab.com")) ?
      try(var.registries["registry.gitlab.com"].username, "") : ""
    )
    password = try(coalesce(var.argocd.git.password, ""), "") != "" ? var.argocd.git.password : (
      (can(regex("gitlab.com", try(var.argocd.git.repo, ""))) &&
      contains(keys(var.registries), "registry.gitlab.com")) ?
      try(var.registries["registry.gitlab.com"].password, "") : ""
    )
  }
}
