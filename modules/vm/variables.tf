variable "nodes" {
  default = ["pve1"]
}

variable "prefix" {
  default = "vm"
}

variable "count_per_node" {
  default = 1
}

variable "tags" {
  default = ""
}

variable "network_bridge" {
  type = string
}

variable "ssh_public_keys_b64" {
  type = string
}

variable "onboot" {
  default = true
}

variable "user" {
  default = "admin"
}

variable "sockets" {
  default = 1
}

variable "cores" {
  default = 0
}

variable "vcpus" {
  default = 2
}

variable "cpu" {
  type    = string
  default = "kvm64"
}

variable "memory" {
  default = 2048
}

variable "disk_size" {
  default = 20
}

variable "disk_storage" {
  default = "rbd"
}

variable "clone" {
  default = "template-debian-12"
}

variable "worker_node_data_disk_storage" {
  default = ""
}

variable "worker_node_data_disk_size" {
  default = 10
}

variable "ipv4" {
  default = "dhcp"
}

variable "ipv6" {
  default = false
}

variable "protection" {
  default = false
}

variable "display" {
  default = "qxl"
}

variable "node_count" {
  default = 0
}
