variable "tenant" {
  default = ""
}

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

variable "pfsense_iso" {
  default = "pfSense-CE-2.7.2-RELEASE-amd64.iso"
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

variable "image" {
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
  default = "nbg1"
  validation {
    condition = contains([
      "nbg1", "fsn1", "hel1", "ash", "hil"
    ], var.location)
    error_message = "invalid location"
  }
}

variable "network" {
  type = object({
    lan = object({
      subnet = string
    })
  })
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
        "cpx11", "cpx21", "cpx31", "cpx41", "cpx51",
        "cax11", "cax21", "cax31", "cax41",
        "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63",
        "cx22", "cx32", "cx42", "cx52"
      ], group.type)
    ])
    error_message = "invalid type"
  }
}
