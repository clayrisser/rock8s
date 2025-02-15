terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.1"
    }
  }
  backend "local" {}
}

provider "hcloud" {
  token = var.hetzner_token
}
