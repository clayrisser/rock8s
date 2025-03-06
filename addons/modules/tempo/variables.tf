variable "enabled" {
  default = true
}

variable "namespace" {
  default = "tempo"
}

variable "chart_version" {
  default = "1.7.1"
}

variable "retention" {
  default = "168h" # 7 days
}

variable "endpoint" {
  type = string
}

variable "access_key" {
  default = ""
}

variable "secret_key" {
  default   = ""
  sensitive = true
}

variable "grafana_repo" {
  type = string
}

variable "bucket" {
  type = string
}

variable "rancher_cluster_id" {
  type = string
}

variable "rancher_project_id" {
  type = string
}
