variable "enabled" {
  default = true
}

variable "namespace" {
  default = "cattle-logging-system"
}

variable "chart_version" {
  default = "102.0.1+up3.17.10"
}

variable "retention" {
  default = "168h" # 7 days
}

variable "region" {
  default = "us-east-1"
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
