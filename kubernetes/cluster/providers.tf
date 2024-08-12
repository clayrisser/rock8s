terraform {
  backend "local" {
    path = "/home/admin/shared/apps/kubernetes/cluster.tfstate"
  }
  required_version = ">=1.3.3"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.10.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.21.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.4"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = "6.0.3"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
    # config_context = "terraform"
  }
}

provider "kubernetes" {
  # host     = local.cluster_endpoint
  # insecure = true
  config_path = var.kubeconfig
  # config_context = "terraform"
}

provider "kubectl" {
  # host     = local.cluster_endpoint
  insecure = true
  config_path = var.kubeconfig
  # exec {
  #   api_version = local.user_exec.api_version
  #   command     = local.user_exec.command
  #   args        = local.user_exec.args
  # }
}

provider "tls" {}

provider "kustomization" {
  context        = "terraform"
  kubeconfig_raw = local.kubeconfig
}
