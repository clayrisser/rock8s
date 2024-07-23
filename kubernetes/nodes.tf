module "k8s_control_plane_nodes" {
  source              = "./modules/proxmox_vm"
  node_count          = var.k8s_control_plane_node_count
  proxmox_node        = var.proxmox_node
  clone            = var.clone
  name_prefix      = "vm-${local.cluster_name}-cp"
  max_vcpus        = var.max_vcpus
  vcpus            = var.k8s_control_plane_vcpus
  sockets          = var.sockets
  cpu_type         = var.cpu_type
  memory_mb        = var.k8s_control_plane_memory
  os_disk_storage  = var.os_disk_storage
  os_disk_size_gb  = var.k8s_control_plane_disk_size
  network_bridge         = var.internal_network_bridge
  user             = var.user
  tags             = "${var.cluster_prefix};terraform;k8s_control_plane"
  ssh_public_keys_b64 = var.ssh_public_keys_b64
}

module "k8s_worker_nodes" {
  source                        = "./modules/proxmox_vm"
  node_count                    = var.k8s_worker_node_count
  proxmox_node                  = var.proxmox_node
  clone                      = var.clone
  name_prefix                = "vm-${local.cluster_name}-worker"
  max_vcpus                  = var.max_vcpus
  vcpus                      = var.k8s_worker_vcpus
  sockets                    = var.sockets
  cpu_type                   = var.cpu_type
  memory_mb                  = var.k8s_worker_memory
  os_disk_storage            = var.os_disk_storage
  os_disk_size_gb            = var.k8s_worker_disk_size
  network_bridge                   = var.internal_network_bridge
  user                       = var.user
  tags                       = "${var.cluster_prefix};terraform;k8s_worker"
  ssh_public_keys_b64           = var.ssh_public_keys_b64
  worker_node_data_disk_storage = var.worker_node_data_disk_storage
  worker_node_data_disk_size    = var.worker_node_data_disk_size
}

output "k8s_control_plane" {
  value = module.k8s_control_plane_nodes.list
}

output "k8s_worker" {
  value = module.k8s_worker_nodes.list
}
