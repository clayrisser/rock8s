variable "rancher_admin_password" {
  default = "rancherP@ssw0rd"
}

variable "kanister_bucket" {
  type = string
}

variable "rancher" {
  default = false
}

variable "cluster_issuer" {
  default = true
}

variable "external_dns" {
  default = true
}

variable "flux" {
  default = true
}

variable "kanister" {
  default = true
}

variable "rancher_logging" {
  default = false
}

variable "kubeconfig" {
  default = "~/.kube/config"
}

variable "ingress_nginx" {
  default = true
}

variable "olm" {
  default = true
}

variable "rancher_istio" {
  default = false
}

variable "rancher_monitoring" {
  default = true
}

variable "longhorn" {
  default = false
}

variable "reloader" {
  default = true
}

variable "argocd" {
  default = true
}

variable "karpenter" {
  default = true
}

variable "kyverno" {
  default = true
}

variable "crossplane" {
  default = false
}

variable "tempo" {
  default = false
}

variable "integration_operator" {
  default = true
}

variable "retention_hours" {
  default = 168
}

variable "ingress_ports" {
  default = [
    "80",
    "443"
  ]
}

variable "email" {
  default = ""
}

variable "rancher_token" {
  default = ""
}

variable "rancher_hostname" {
  default = ""
}

variable "ceph" {
  default = false
}

variable "ceph_monitors" {
  type    = list(string)
  default = []
}

variable "ceph_admin_id" {
  default = ""
}

variable "ceph_admin_key" {
  default = ""
}

variable "ceph_cluster_id" {
  default = ""
}

variable "ceph_rbd_pool" {
  default = "rbd"
}

variable "hetzner_api_key" {
  default = ""
}

variable "ceph_fs_name" {
  default = "cephfs"
}

variable "pdns_api_url" {
  default = ""
}

variable "pdns_api_key" {
  default = ""
}

variable "cloudflare_api_key" {
  default = ""
}

variable "cloudflare_email" {
  default = ""
}

variable "entrypoint" {
  default = ""
}

variable "git_username" {
  default = ""
}

variable "git_password" {
  default = ""
}

variable "git_repo" {
  default = ""
}

variable "s3" {
  default = true
}

variable "s3_endpoint" {
  default = ""
}

variable "s3_access_key" {
  default = ""
}

variable "s3_secret_key" {
  default = ""
}

variable "vault" {
  default = false
}

variable "openebs" {
  default = true
}

variable "registries" {
  type = map(object({
    username = optional(string)
    password = optional(string)
    token    = optional(string)
  }))
  default = {}
}
