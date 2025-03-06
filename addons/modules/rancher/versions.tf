terraform {
  required_version = ">= 1.0"
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">= 3.2.0"
    }
  }
}
