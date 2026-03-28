terraform {
  backend "local" {}
  required_version = ">= 1.6.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.7.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.1"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 13.1.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5.0"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 7.15.1"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

provider "kubectl" {
  insecure    = true
  config_path = var.kubeconfig
}

provider "tls" {}
