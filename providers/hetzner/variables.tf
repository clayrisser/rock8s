variable "hetzner_token" {
  type      = string
  sensitive = true
}

variable "purpose" {
  type = string
  validation {
    condition     = contains(["pfsense", "master", "worker"], var.purpose)
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

variable "ssh_public_key_path" {
  type = string
}

variable "server_image" {
  default = "debian-12"
  validation {
    condition = contains([
      "ubuntu-22.04", "ubuntu-20.04", "debian-11", "debian-12",
      "centos-7", "rocky-9", "fedora-37"
    ], var.server_image)
    error_message = "invalid image"
  }
}

variable "location" {
  type    = string
  default = "nbg1"
  validation {
    condition = contains([
      "nbg1", "fsn1", "hel1", "ash", "hil"
    ], var.location)
    error_message = "invalid location"
  }
}

variable "network_name" {
  type    = string
  default = "private"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.network_name))
    error_message = "lowercase with hyphens only"
  }
}

variable "user_data" {
  type    = string
  default = ""
}

variable "cluster_dir" {
  type = string
}

variable "nodes" {
  type = list(object({
    name    = string
    type    = string
    count   = optional(number)
    options = map(string)
    ipv4s   = optional(list(string))
  }))
  validation {
    condition = alltrue([
      for group in var.nodes :
      contains([
        "cx11", "cx21", "cx31", "cx41", "cx51",
        "cpx11", "cpx21", "cpx31", "cpx41", "cpx51"
      ], group.type) &&
      (group.count == null || group.count > 0)
    ])
    error_message = "invalid type or count"
  }
}
