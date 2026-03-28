variable "enabled" {
  default = true
}

variable "namespace" {
  default = "cattle-monitoring-system"
}

variable "chart_version" {
  default = "108.0.4+up77.9.1-rancher.14"
}

variable "retention" {
  default = "168h" # 7 days
}

variable "retention_size" {
  default = "1GiB"
}

variable "create_namespace" {
  default = true
}
