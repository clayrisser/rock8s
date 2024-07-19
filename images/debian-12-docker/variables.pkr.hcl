variable "iso_storage_pool" {
  default = "local"
}

variable "vm_name" {
  default = "template-debian-12-docker"
}

variable "cpu_type" {
  default = "kvm64"
}

variable "cores" {
  type    = string
  default = "2"
}

variable "iso_file" {
  default = ""
}

variable "disk_format" {
  default = "raw"
}

variable "disk_size" {
  default = "16G"
}

variable "storage_pool" {
  default = "local-lvm"
}

variable "memory" {
  default = "2048"
}

variable "iso_url" {
  default = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso"
}

variable "network_bridge" {
  default = "vmbr20"
}

variable "proxmox_token_id" {
  type = string
}

variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_host" {
  type = string
}

variable "proxmox_node" {
  type = string
}

variable "iso_checksum" {
  type = string
}

variable "network_ip" {
  type = string
}
