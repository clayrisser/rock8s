variable "azure_subscription_id" {
  type      = string
  sensitive = true
}

variable "azure_client_id" {
  type      = string
  sensitive = true
}

variable "azure_client_secret" {
  type      = string
  sensitive = true
}

variable "azure_tenant_id" {
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
  default = "debian-12"
  validation {
    condition = contains([
      "ubuntu-22.04", "ubuntu-20.04", "debian-11", "debian-12",
      "centos-7", "rocky-9", "fedora-37"
    ], var.image)
    error_message = "invalid image"
  }
}

variable "location" {
  type    = string
  default = "westeurope"
  validation {
    condition = contains([
      "eastus", "westus2", "westeurope", "northeurope", "southeastasia", "japaneast"
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
        "Standard_B2s", "Standard_B4ms",
        "Standard_D2s_v5", "Standard_D4s_v5", "Standard_D8s_v5",
        "Standard_D2ps_v5", "Standard_D4ps_v5",
        "Standard_E2s_v5", "Standard_E4s_v5",
        "Standard_F2s_v2", "Standard_F4s_v2"
      ], group.type)
    ])
    error_message = "invalid type"
  }
}
