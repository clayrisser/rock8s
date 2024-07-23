variable "cluster_prefix" {
  default = "test"
}

variable "iteration" {
  default = "0"
}

variable "cluster_domain" {
  default = "local"
}

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

variable "internal_network_bridge" {
  type = string
}

variable "ssh_public_keys_b64" {
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

variable "vm_k8s_control_plane_node_count" {
  default = 1
}

variable "vm_k8s_control_plane_vcpus" {
  default = 2
}

variable "vm_k8s_control_plane_memory" {
  default = 1536
}

variable "vm_k8s_control_plane_disk_size" {
  default = 20
}

variable "vm_k8s_worker_node_count" {
  default = 2
}

variable "vm_k8s_worker_vcpus" {
  default = 2
}

variable "vm_k8s_worker_memory" {
  default = 2048
}

variable "vm_k8s_worker_disk_size" {
  default = 20
}

variable "kube_version" {
  default = "v1.28.11"
}

variable "kube_network_plugin" {
  default = "calico"
}

variable "enable_nodelocaldns" {
  default = false
}

variable "podsecuritypolicy_enabled" {
  default = false
}

variable "persistent_volumes_enabled" {
  default = false
}

variable "helm_enabled" {
  default = false
}

variable "ingress_nginx_enabled" {
  default = false
}

variable "argocd_enabled" {
  default = false
}

variable "argocd_version" {
  default = "v2.4.12"
}

variable "kubespray_data_dir" {
  type = string
}
