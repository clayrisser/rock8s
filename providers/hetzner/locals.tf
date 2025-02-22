locals {
  node_dir             = "${var.cluster_dir}/${var.purpose}"
  node_ssh_private_key = "${local.node_dir}/id_rsa"
  node_ssh_public_key  = "${local.node_dir}/id_rsa.pub"
  tenant               = var.tenant == "default" ? "" : "${var.tenant}"
  nodes = [
    for i, group in var.nodes : {
      type    = group.type
      count   = try(group.count, length(group.ipv4s), 1)
      options = try(group.options, {})
      ipv4s   = group.ipv4s
    }
  ]
  node_configs = flatten([
    for group in local.nodes : [
      for i in range(group.count) : {
        name        = local.tenant == "" ? "${var.cluster_name}-${var.purpose}${i + 1}" : "${local.tenant}-${var.cluster_name}-${var.purpose}${i + 1}"
        server_type = group.type
        options     = group.options
        ipv4        = try(group.ipv4s[i], null)
      }
    ]
  ])
  node_ips = {
    for idx, server in hcloud_server.nodes :
    server.name => server.ipv4_address
  }
  node_private_ips = {
    for idx, server in hcloud_server.nodes :
    server.name => one(server.network).ip
  }
}
