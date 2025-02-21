resource "tls_private_key" "master_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "worker_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "master" {
  name       = "${var.cluster_name}-master"
  public_key = tls_private_key.master_ssh_key.public_key_openssh
}

resource "hcloud_ssh_key" "worker" {
  name       = "${var.cluster_name}-worker"
  public_key = tls_private_key.worker_ssh_key.public_key_openssh
}

resource "local_sensitive_file" "master_private_key" {
  content         = tls_private_key.master_ssh_key.private_key_pem
  filename        = local.master_ssh_private_key
  file_permission = "0600"
}

resource "local_file" "master_public_key" {
  content         = tls_private_key.master_ssh_key.public_key_openssh
  filename        = local.master_ssh_public_key
  file_permission = "0644"
}

resource "local_sensitive_file" "worker_private_key" {
  content         = tls_private_key.worker_ssh_key.private_key_pem
  filename        = local.worker_ssh_private_key
  file_permission = "0600"
}

resource "local_file" "worker_public_key" {
  content         = tls_private_key.worker_ssh_key.public_key_openssh
  filename        = local.worker_ssh_public_key
  file_permission = "0644"
}

data "hcloud_network" "network" {
  name = var.network_name
}

resource "hcloud_server" "nodes" {
  count       = length(local.node_configs)
  name        = local.node_configs[count.index].name
  server_type = local.node_configs[count.index].server_type
  image       = try(local.node_configs[count.index].options.image, var.server_image)
  location    = try(local.node_configs[count.index].options.location, var.location)
  ssh_keys    = [local.node_configs[count.index].is_master ? hcloud_ssh_key.master.id : hcloud_ssh_key.worker.id]
  user_data   = var.user_data != "" ? var.user_data : null
  network {
    network_id = data.hcloud_network.network.id
  }
}
