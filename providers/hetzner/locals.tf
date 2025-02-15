locals {
  master_ips = [
    for idx, server in hcloud_server.nodes :
    server.ipv4_address
    if idx < var.master_count
  ]
  worker_ips = [
    for idx, server in hcloud_server.nodes :
    server.ipv4_address
    if idx >= var.master_count
  ]
}
