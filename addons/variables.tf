variable "kubeconfig" {
  default = "~/.kube/config"
}

variable "ingress_ports" {
  default = [
    "80",
    "443"
  ]
}

variable "entrypoint" {
  default = ""
}

variable "email" {
  default = ""
}

variable "rancher" {
  type = object({
    admin_password = optional(string, "rancherP@ssw0rd")
    cluster_id     = optional(string)
    hostname       = optional(string)
    token          = optional(string)
  })
  default = null
}

variable "cluster_issuer" {
  default = null
}

variable "external_dns" {
  type = object({
    provider = optional(string)
    powerdns = optional(object({
      api_url = optional(string)
      api_key = optional(string)
    }))
    cloudflare = optional(object({
      email   = optional(string)
      api_key = optional(string)
    }))
    hetzner = optional(object({
      api_key = optional(string)
    }))
  })
  default = null
}

variable "flux" {
  default = null
}

variable "kanister" {
  type = object({
    bucket = optional(string)
  })
  default = null
}

variable "rancher_logging" {
  default = null
}

variable "ingress_nginx" {
  type = object({
    load_balancer = optional(bool, true)
  })
  default = null
}

variable "olm" {
  default = null
}

variable "rancher_istio" {
  default = null
}

variable "rancher_monitoring" {
  default = null
}

variable "reloader" {
  default = null
}

variable "argocd" {
  type = object({
    git = optional(object({
      repo     = optional(string)
      username = optional(string)
      password = optional(string)
    }))
  })
  default = null
}

variable "karpenter" {
  default = null
}

variable "kyverno" {
  default = null
}

variable "crossplane" {
  default = null
}

variable "tempo" {
  type = object({
    retention_hours = optional(number, 168)
  })
  default = null
}

variable "integration_operator" {
  default = null
}

variable "ceph" {
  type = object({
    monitors   = optional(list(string), [])
    admin_id   = optional(string, "")
    admin_key  = optional(string, "")
    cluster_id = optional(string, "")
    rbd_pool   = optional(string, "rbd")
    fs_name    = optional(string, "cephfs")
  })
  default = null
}

variable "s3" {
  type = object({
    endpoint   = optional(string)
    access_key = optional(string)
    secret_key = optional(string)
  })
  default = null
}

variable "vault" {
  default = null
}

variable "openebs" {
  default = null
}

variable "longhorn" {
  type = object({
    s3_bucket     = optional(string)
    s3_access_key = optional(string)
    s3_secret_key = optional(string)
    s3_endpoint   = optional(string)
  })
  default = null
}

variable "registries" {
  type = map(object({
    username = optional(string)
    password = optional(string)
    token    = optional(string)
  }))
  default = {}
}
