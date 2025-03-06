variable "enabled" {
  default = true
}

variable "namespace" {
  default = "cert-manager"
}

variable "issuers" {
  default = {
    cloudflare  = true
    letsencrypt = true
    route53     = null
    selfsigned  = true
    pdns        = null
    hetzner     = null
  }
}

variable "letsencrypt_email" {
  type = string
}
