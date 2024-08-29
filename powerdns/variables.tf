variable "proxmox_nodes" {
  type = list(string)
}

variable "proxmox_token_id" {
  type = string
}

variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_tls_insecure" {
  type = bool
}

variable "proxmox_host" {
  type = string
}

variable "proxmox_parallel" {
  default = 2
}

variable "proxmox_timeout" {
  default = 600
}

variable "network_bridge" {
  type = string
}

variable "ssh_public_keys_b64" {
  type      = string
  sensitive = true
}

variable "ssh_private_key_b64" {
  type      = string
  sensitive = true
}

variable "user" {
  default = "admin"
}

variable "sockets" {
  default = 1
}

variable "cpu" {
  default = "host"
}

variable "disk_storage" {
  default = "rbd"
}

variable "clone" {
  default = "template-debian-12-docker"
}

variable "vcpus" {
  default = 2
}

variable "memory" {
  default = 2048
}

variable "disk_size" {
  default = 20
}

variable "protection" {
  default = false
}

variable "node_count" {
  default = 2
}

variable "nameservers" {
  type = string
  validation {
    condition     = length(var.nameservers) > 0
    error_message = "must not be empty"
  }
}
