terraform {
  backend "local" {}
  required_version = ">=1.3.3"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
}

provider "proxmox" {
  pm_api_token_id     = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret
  pm_api_url          = "https://${var.proxmox_host}/api2/json"
  pm_parallel         = var.proxmox_parallel
  pm_timeout          = var.proxmox_timeout
  pm_tls_insecure     = var.proxmox_tls_insecure
}
