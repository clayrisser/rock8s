variable "ovh_application_key" {
  type      = string
  sensitive = true
}

variable "ovh_application_secret" {
  type      = string
  sensitive = true
}

variable "ovh_consumer_key" {
  type      = string
  sensitive = true
}

variable "ovh_tenant_name" {
  type      = string
  sensitive = true
}

variable "ovh_openstack_user" {
  type      = string
  sensitive = true
}

variable "ovh_openstack_password" {
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
  default = "Debian 12"
  validation {
    condition = contains([
      "Debian 12", "Debian 11",
      "Ubuntu 22.04", "Ubuntu 20.04",
      "Rocky Linux 9", "Fedora 37"
    ], var.image)
    error_message = "invalid image"
  }
}

variable "location" {
  type    = string
  default = "GRA7"
  validation {
    condition = contains([
      "GRA7", "GRA9", "GRA11", "SBG5", "BHS5", "WAW1", "UK1", "DE1"
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
        "b2-7", "b2-15", "b2-30", "b2-60", "b2-120",
        "c2-7", "c2-15", "c2-30", "c2-60",
        "d2-2", "d2-4", "d2-8"
      ], group.type)
    ])
    error_message = "invalid type"
  }
}
