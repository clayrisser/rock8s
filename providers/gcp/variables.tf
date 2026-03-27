variable "gcp_project" {
  type = string
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
  default = "europe-west1"
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-west1",
      "europe-west1", "europe-west3",
      "asia-southeast1", "asia-northeast1"
    ], var.location)
    error_message = "invalid location (region)"
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
        "e2-medium",
        "e2-standard-2", "e2-standard-4", "e2-standard-8",
        "n2-standard-2", "n2-standard-4", "n2-standard-8",
        "n2d-standard-2", "n2d-standard-4",
        "t2a-standard-1", "t2a-standard-2", "t2a-standard-4",
        "c3-standard-4",
      ], group.type)
    ])
    error_message = "invalid machine type"
  }
}
