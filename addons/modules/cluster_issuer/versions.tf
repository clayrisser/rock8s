terraform {
  required_version = ">= 1.0"
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.5.0"
    }
  }
}
