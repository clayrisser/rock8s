variable "enabled" {
  default = true
}

variable "namespace" {
  default = "cattle-monitoring-system"
}

variable "chart_version" {
  default = "102.0.2+up40.1.2"
}

variable "endpoint" {
  default = "us-east-1"
}

variable "retention" {
  default = "168h" # 7 days
}

variable "retention_size" {
  default = "1GiB"
}

variable "retention_resolution_5m" {
  default = "720h" # 30 days
}

variable "retention_resolution_1h" {
  default = "8766h" # 1 year
}

variable "access_key" {
  default = ""
}

variable "secret_key" {
  default   = ""
  sensitive = true
}

variable "bucket" {
  default = ""
}

variable "create_namespace" {
  default = true
}
