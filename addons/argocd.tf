module "argocd" {
  source  = "./modules/argocd"
  enabled = var.argocd
}

data "kubernetes_secret" "argocd-initial-admin-secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }
  depends_on = [
    module.argocd
  ]
}

provider "argocd" {
  username                    = "admin"
  password                    = try(data.kubernetes_secret.argocd-initial-admin-secret.data.password, null)
  port_forward_with_namespace = "argocd"
  kubernetes {
    host                   = local.kubeconfig_json.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig_json.clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig_json.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig_json.users[0].user["client-key-data"])
  }
}

resource "argocd_repository" "git" {
  count    = (var.argocd && var.git_repo != "") ? 1 : 0
  repo     = var.git_repo
  username = local.git_username
  password = local.git_password
  insecure = false
}

resource "argocd_application" "apps" {
  count = length(argocd_repository.git)
  metadata {
    name      = "apps"
    namespace = "argocd"
  }
  spec {
    project = "default"
    source {
      repo_url        = argocd_repository.git[0].repo
      target_revision = "main"
      path            = "apps"
      directory {
        recurse = false
      }
    }
    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "argocd"
    }
    sync_policy {
      sync_options = [
        "CreateNamespace=true"
      ]
    }
  }
}
