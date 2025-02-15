terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.2"
    }
  }
  backend "local" {}
}

provider "hcloud" {
  token = var.hetzner_token
}
