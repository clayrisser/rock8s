variable "hetzner_token" {
  type      = string
  sensitive = true
}

variable "cluster_name" {
  type = string
}

variable "server_image" {
  type = string
}

variable "location" {
  type = string
}

variable "network_name" {
  type = string
}

variable "user_data" {
  type    = string
  default = ""
}

variable "cluster_dir" {
  type = string
}

variable "master_groups" {
  type = list(object({
    type    = string
    count   = number
    options = map(string)
  }))
}

variable "worker_groups" {
  type = list(object({
    type    = string
    count   = number
    options = map(string)
  }))
}
