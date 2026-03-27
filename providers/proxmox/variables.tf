variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_insecure" {
  type    = bool
  default = true
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "purpose" {
  type = string
  validation {
    condition     = contains(["master", "worker"], var.purpose)
    error_message = "invalid purpose (proxmox supports master and worker only)"
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

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "content_datastore_id" {
  type    = string
  default = "local"
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
