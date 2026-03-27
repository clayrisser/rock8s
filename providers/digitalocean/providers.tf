terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "digitalocean" {
  token = var.digitalocean_token
}
