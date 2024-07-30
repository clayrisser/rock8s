module "k8s_control_plane_nodes" {
  source              = "../modules/vm"
  clone               = var.clone
  count_per_node      = 1
  cpu                 = var.cpu
  ipv6                = true
  max_vcpus           = var.max_vcpus
  memory              = var.control_plane_memory
  network_bridge      = var.internal_network_bridge
  nodes               = var.proxmox_nodes
  os_disk_size        = var.control_plane_disk_size
  os_disk_storage     = var.os_disk_storage
  prefix              = "vm-${local.cluster_name}-cp"
  sockets             = var.sockets
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  tags                = "${var.cluster_prefix};terraform;k8s_control_plane"
  user                = var.user
  vcpus               = var.control_plane_vcpus
}

module "k8s_worker_nodes" {
  source              = "../modules/vm"
  clone               = var.clone
  count_per_node      = 1
  cpu                 = var.cpu
  ipv6                = true
  max_vcpus           = var.max_vcpus
  memory              = var.worker_memory
  network_bridge      = var.internal_network_bridge
  nodes               = var.proxmox_nodes
  os_disk_size        = var.worker_disk_size
  os_disk_storage     = var.os_disk_storage
  prefix              = "vm-${local.cluster_name}-worker"
  sockets             = var.sockets
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  tags                = "${var.cluster_prefix};terraform;k8s_worker"
  user                = var.user
  vcpus               = var.worker_vcpus
  # worker_node_data_disk_storage = var.worker_node_data_disk_storage
  # worker_node_data_disk_size    = var.worker_node_data_disk_size
}

output "k8s_control_plane" {
  value = module.k8s_control_plane_nodes.list
}

output "k8s_worker" {
  value = module.k8s_worker_nodes.list
}
