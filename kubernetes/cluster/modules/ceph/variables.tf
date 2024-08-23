variable "enabled" {
  default = true
}

variable "cephfs_version" {
  default = "3.12.1"
}

variable "rbd_version" {
  default = "3.12.1"
}

variable "monitors" {
  default = ""
}

variable "admin_id" {
  default = ""
}

variable "admin_key" {
  default = ""
}

variable "cluster_id" {
  default = ""
}

variable "pool" {
  default = "rbd"
}

variable "fs_name" {
  default = "cephfs"
}
