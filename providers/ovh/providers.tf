terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.45"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

provider "openstack" {
  auth_url    = "https://auth.cloud.ovh.net/v3"
  domain_name = "Default"
  tenant_name = var.ovh_tenant_name
  user_name   = var.ovh_openstack_user
  password    = var.ovh_openstack_password
  region      = var.location
}
