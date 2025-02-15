resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "default" {
  name       = var.ssh_key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${var.provider_dir}/id_rsa"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${var.provider_dir}/id_rsa.pub"
  file_permission = "0644"
}

resource "hcloud_server" "nodes" {
  count       = length(local.node_configs)
  name        = local.node_configs[count.index].name
  server_type = local.node_configs[count.index].server_type
  image       = var.server_image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]
  network {
    network_id = hcloud_network.network.id
  }
  depends_on = [
    hcloud_network_subnet.subnet
  ]
}

resource "hcloud_network" "network" {
  name     = "${var.cluster_name}-network"
  ip_range = var.network_ip_range
}

resource "hcloud_network_subnet" "subnet" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_ip_range
}

resource "local_file" "env_file" {
  content  = <<-EOT
MASTER_IPS=${join(",", local.master_ips)}
WORKER_IPS=${join(",", local.worker_ips)}
SSH_PRIVATE_KEY=${var.provider_dir}/id_rsa
IP_RANGE=${var.network_ip_range}
CLUSTER_ENTRYPOINT=${var.cluster_entrypoint}
EOT
  filename = "${var.provider_dir}/.env.output"
}
