variable "hetzner_token" {
  type      = string
  sensitive = true
}

variable "data_dir" {
  type = string
}

variable "ssh_key_name" {
  default = "default"
}

variable "masters" {
  type = string
}

variable "workers" {
  type = string
}

variable "cluster_name" {
  default = "rock8s"
}

variable "server_type" {
  default = "cx21"
}

variable "server_image" {
  default = "ubuntu-22.04"
}

variable "location" {
  default = "nbg1"
}

variable "network_ip_range" {
  default = "10.0.0.0/16"
}

variable "network_zone" {
  default = "eu-central"
}

variable "subnet_ip_range" {
  default = "10.0.1.0/24"
}

variable "cluster_entrypoint" {
  type = string
}

variable "provider_dir" {
  type = string
}
