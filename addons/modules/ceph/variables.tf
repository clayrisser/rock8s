variable "enabled" {
  default = true
}

variable "cephfs_version" {
  default = "3.16.2"
}

variable "rbd_version" {
  default = "3.16.2"
}

variable "monitors" {
  type    = list(string)
  default = []
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
