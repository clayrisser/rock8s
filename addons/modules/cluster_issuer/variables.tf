variable "enabled" {
  default = true
}

variable "namespace" {
  default = "cert-manager"
}

variable "issuers" {
  default = {
    cloudflare   = true
    letsencrypt  = true
    route53      = null
    selfsigned   = true
    pdns         = null
    hetzner      = null
    digitalocean = null
  }
}

variable "letsencrypt_email" {
  type = string
}

variable "hetzner_webhook_version" {
  default = "1.4.2"
}
