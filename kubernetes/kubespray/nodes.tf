module "k8s_control_plane_nodes" {
  source              = "../../modules/vm"
  clone               = var.clone
  count_per_node      = 1
  cpu                 = var.cpu
  ipv6                = true
  memory              = var.control_plane_memory
  network_bridge      = var.internal_network_bridge
  nodes               = var.single_control_plane ? [var.proxmox_nodes[0]] : var.proxmox_nodes
  disk_size           = var.control_plane_disk_size
  disk_storage        = var.control_plane_disk_storage
  prefix              = "${var.prefix}-${var.iteration}-control-plane"
  sockets             = var.sockets
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  tags                = "${var.prefix}_${var.iteration};terraform;k8s;k8s_control_plane"
  user                = var.user
  vcpus               = var.control_plane_vcpus
}

module "k8s_worker_nodes" {
  source              = "../../modules/vm"
  clone               = var.clone
  count_per_node      = 1
  cpu                 = var.cpu
  ipv6                = true
  memory              = var.worker_memory
  network_bridge      = var.internal_network_bridge
  nodes               = var.proxmox_nodes
  disk_size           = var.worker_disk_size
  disk_storage        = var.worker_disk_storage
  prefix              = "${var.prefix}-${var.iteration}-worker"
  sockets             = var.sockets
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  tags                = "${var.prefix}_${var.iteration};terraform;k8s;k8s_worker"
  user                = var.user
  vcpus               = var.worker_vcpus
}

output "k8s_control_plane" {
  value = module.k8s_control_plane_nodes.list
}

output "k8s_worker" {
  value = module.k8s_worker_nodes.list
}
