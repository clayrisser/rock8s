variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
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
}

variable "location" {
  type    = string
  default = "eu-central-1"
  validation {
    condition = contains([
      "us-east-1",
      "us-west-2",
      "eu-west-1",
      "eu-central-1",
      "ap-southeast-1",
      "ap-northeast-1",
    ], var.location)
    error_message = "invalid AWS region"
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
        "t3.medium", "t3.large", "t3.xlarge",
        "m5.large", "m5.xlarge", "m5.2xlarge",
        "m6g.medium", "m6g.large", "m6g.xlarge",
        "c5.large", "c5.xlarge",
        "c6g.large", "c6g.xlarge",
        "r5.large", "r5.xlarge",
      ], group.type)
    ])
    error_message = "invalid instance type"
  }
}
