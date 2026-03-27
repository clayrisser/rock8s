variable "libvirt_uri" {
  type    = string
  default = "qemu:///system"
}

variable "purpose" {
  type = string
  validation {
    condition     = contains(["master", "worker"], var.purpose)
    error_message = "invalid purpose (libvirt supports master and worker only)"
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
  default = ""
}

variable "network" {
  type = any
}

variable "pool" {
  type    = string
  default = "default"
}

variable "firmware" {
  type    = string
  default = ""
}

variable "arch" {
  type    = string
  default = ""
}

variable "machine" {
  type    = string
  default = ""
}

variable "cpu_mode" {
  type    = string
  default = ""
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
      contains(["small", "medium", "large", "xlarge"], group.type)
    ])
    error_message = "invalid type (must be: small, medium, large, xlarge)"
  }
}
