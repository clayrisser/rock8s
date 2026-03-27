variable "digitalocean_token" {
  type      = string
  sensitive = true
}

variable "purpose" {
  type = string
  validation {
    condition     = contains(["master", "worker"], var.purpose)
    error_message = "invalid purpose"
  }
}

variable "cluster_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.cluster_name))
    error_message = "lowercase with hyphens only"
  }
}

variable "image" {
  type    = string
  default = "debian-12-x64"
}

variable "location" {
  type    = string
  default = "fra1"
  validation {
    condition = contains([
      "nyc1", "nyc3", "sfo3", "lon1", "fra1", "ams3", "sgp1", "blr1", "syd1"
    ], var.location)
    error_message = "invalid location"
  }
}

variable "network" {
  type = any
}

variable "nodes" {
  type = list(object({
    type      = string
    count     = optional(number)
    image     = optional(string)
    ipv4s     = optional(list(string))
    hostnames = optional(list(string))
  }))
  validation {
    condition = alltrue([
      for group in var.nodes :
      contains([
        "s-2vcpu-4gb", "s-4vcpu-8gb", "s-8vcpu-16gb",
        "g-2vcpu-8gb", "g-4vcpu-16gb",
        "gd-2vcpu-8gb", "gd-4vcpu-16gb",
        "m-2vcpu-16gb", "m-4vcpu-32gb",
        "c-2", "c-4", "c-8"
      ], group.type)
    ])
    error_message = "invalid type"
  }
}
