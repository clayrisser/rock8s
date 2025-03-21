module "argocd" {
  source  = "./modules/argocd"
  enabled = var.argocd != null
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
  count    = (var.argocd != null && try(var.argocd.git.repo, "") != "") ? 1 : 0
  repo     = local.git.repo
  username = local.git.username
  password = local.git.password
  insecure = false
}

resource "time_sleep" "wait" {
  count           = (var.argocd != null && try(var.argocd.git.repo, "") != "") ? 1 : 0
  create_duration = "10s"
  depends_on = [
    argocd_repository.git
  ]
}

resource "argocd_application" "apps" {
  count = (var.argocd != null && local.git.repo != "") ? 1 : 0
  metadata {
    name      = "apps"
    namespace = "argocd"
  }
  spec {
    project = "default"
    source {
      repo_url        = local.git.repo
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
  depends_on = [
    time_sleep.wait
  ]
}
