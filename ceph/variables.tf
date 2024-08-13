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

variable "os_disk_storage" {
  default = "rbd"
}

variable "worker_node_data_disk_storage" {
  default = "rbd"
}

variable "worker_node_data_disk_size" {
  default = 10
}

variable "clone" {
  default = "template-debian-12"
}

variable "vcpus" {
  default = 2
}

variable "memory" {
  default = 1536
}

variable "disk_size" {
  default = 20
}

variable "s3_access_key" {
  type = string
}

variable "s3_secret_key" {
  type = string
  # sensitive = true
}
