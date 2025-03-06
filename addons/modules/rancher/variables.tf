variable "enabled" {
  default = true
}

variable "rancher_cluster_id" {
  default = "local"
}

variable "rancher_admin_password" {
  default = "rancherP@ssw0rd"
}

variable "chart_version" {
  default = "v2.8.0"
}

variable "namespace" {
  default = "cattle-system"
}

variable "values" {
  default = ""
}

variable "rancher_token" {
  default = ""
}

variable "letsencrypt_email" {
  type = string
}

variable "rancher_hostname" {
  type = string
}

variable "kubeconfig" {
  type = string
}
