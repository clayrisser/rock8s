variable "cluster_prefix" {
  default = "kops"
}

variable "iteration" {
  default = 0
}

variable "rancher_admin_password" {
  default = "rancherP@ssw0rd"
}

variable "kanister_bucket" {
  default = ""
}

variable "api_strategy" {
  default = "LB"
  validation {
    condition     = contains(["DNS", "LB"], var.api_strategy)
    error_message = "Allowed values for entrypoint_strategy are \"DNS\" or \"LB\"."
  }
}

variable "rancher" {
  default = false
}

variable "cluster_issuer" {
  default = false
}

variable "external_dns" {
  default = false
}

variable "flux" {
  default = false
}

variable "kanister" {
  default = false
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
  default = false
}

variable "rancher_istio" {
  default = false
}

variable "rancher_monitoring" {
  default = false
}

variable "longhorn" {
  default = false
}

variable "reloader" {
  default = false
}

variable "argocd" {
  default = false
}

variable "karpenter" {
  default = false
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
  default = false
}

variable "retention_hours" {
  default = 168
}

variable "ingress_ports" {
  default = "80,443"
}

variable "email" {
  type = string
}

variable "rancher_token" {
  type = string
}

variable "rancher_hostname" {
  default = ""
}

variable "ceph" {
  default = true
}

variable "ceph_monitors" {
  default = ""
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

variable "ceph_fs_name" {
  default = "cephfs"
}

variable "pdns_api_url" {
  default = ""
}

variable "pdns_api_key" {
  default = ""
}

variable "cluster_entrypoint" {
  default = ""
}

variable "gitlab_hostname" {
  default = "gitlab.com"
}

variable "gitlab_username" {
  default = ""
}

variable "gitlab_token" {
  default = ""
}

variable "gitlab_repo" {
  default = ""
}

variable "s3" {
  default = false
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
