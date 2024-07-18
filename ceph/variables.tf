variable "proxmox_host" {
  type = string
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

variable "proxmox_node" {
  type = string
}

variable "proxmox_parallel" {
  default = 2
}

variable "proxmox_timeout" {
  default = 600
}

variable "internal_net_name" {
  type = string
}

variable "internal_net_subnet_cidr" {
  type = string
}

variable "ssh_public_keys_b64" {
  type      = string
  sensitive = true
}

variable "ssh_private_key_b64" {
  type = string
}

variable "vm_user" {
  default = "admin"
}

variable "vm_sockets" {
  default = 1
}

variable "vm_max_vcpus" {
  default = 2
}

variable "vm_cpu_type" {
  default = "kvm64"
}

variable "vm_os_disk_storage" {
  default = "rbd"
}

variable "worker_node_data_disk_storage" {
  default = "rbd"
}

variable "worker_node_data_disk_size" {
  default = 10
}

variable "vm_clone" {
  default = "template-debian-12"
}

variable "vm_count" {
  default = 1
}

variable "vm_vcpus" {
  default = 2
}

variable "vm_memory" {
  default = 1536
}

variable "vm_disk_size" {
  default = 20
}
