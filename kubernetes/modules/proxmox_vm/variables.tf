variable "proxmox_node" {
  default = "pve1"
}

variable "vm_name_prefix" {
  default = "vm"
}

variable "node_count" {
  default = 1
}

variable "vm_tags" {
  default = ""
}

variable "vm_net_name" {
  type = string
}

variable "vm_net_subnet_cidr" {
  type = string
}

variable "ssh_public_keys_b64" {
  type = string
}

variable "vm_onboot" {
  default = true
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

variable "vm_vcpus" {
  default = 2
}

variable "vm_cpu_type" {
  type        = string
  description = "The type of CPU to emulate in the Guest"
  default     = "host"
}

variable "vm_memory_mb" {
  default = 2048
}

variable "vm_os_disk_size_gb" {
  default = 20
}

variable "vm_os_disk_storage" {
  default = "rbd"
}

variable "vm_clone" {
  default = "template-debian-12"
}

variable "worker_node_data_disk_storage" {
  default = ""
}

variable "worker_node_data_disk_size" {
  default = 10
}
