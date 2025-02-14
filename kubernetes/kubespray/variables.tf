variable "prefix" {
  type = string
}

variable "iteration" {
  default = "0"
}

variable "user" {
  default = "admin"
}

variable "master_ips" {
  type = list(string)
}

variable "worker_ips" {
  type = list(string)
}

variable "ssh_private_key" {
  type = string
}

variable "kubespray_version" {
  default = "v2.24.0"
}

variable "kube_version" {
  default = "v1.28.11"
}

variable "kube_network_plugin" {
  default = "calico"
}

variable "pod_network_cidr" {
  default = "10.244.0.0/16"
}

variable "service_network_cidr" {
  default = "10.96.0.0/12"
}

variable "node_local_dns" {
  default = false
}

variable "app_dir" {
  type = string
}

variable "ip_range" {
  type = string
}

variable "single_control_plane" {
  default = false
}

variable "ceph_provisioner_monitors" {
  default = ""
}

variable "ceph_provisioner_admin_id" {
  default = ""
}

variable "ceph_provisioner_secret" {
  default = ""
}

variable "cluster_entrypoint" {
  type = string
}

variable "protection" {
  default = false
}

variable "dualstack" {
  default = true
}
