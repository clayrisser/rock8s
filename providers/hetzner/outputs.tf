output "master_ips" {
  value = {
    for idx, server in hcloud_server.nodes :
    server.name => server.ipv4_address
    if idx < var.master_count
  }
}

output "worker_ips" {
  value = {
    for idx, server in hcloud_server.nodes :
    server.name => server.ipv4_address
    if idx >= var.master_count
  }
}

output "master_private_ips" {
  value = {
    for idx, server in hcloud_server.nodes :
    server.name => server.network[0].ip
    if idx < var.master_count
  }
}

output "worker_private_ips" {
  value = {
    for idx, server in hcloud_server.nodes :
    server.name => server.network[0].ip
    if idx >= var.master_count
  }
}

output "server_ids" {
  value = {
    for server in hcloud_server.nodes :
    server.name => server.id
  }
}

output "ssh_key_fingerprint" {
  value = hcloud_ssh_key.default.fingerprint
}

output "data_dir" {
  value = pathexpand("~/.local/share/rock8s/${var.cluster_name}")
}

output "provider_dir" {
  value = var.provider_dir
}

output "env_file" {
  value = "${var.provider_dir}/.env.output"
}

output "ssh_private_key" {
  value = "${var.provider_dir}/id_rsa"
}
