locals {
  tenant               = var.tenant == "" || var.tenant == null || var.tenant == "default" ? "" : var.tenant
  node_ssh_private_key = "${var.cluster_dir}/${var.purpose}/id_rsa"
  node_configs = flatten([
    for group in var.nodes : [
      for i in range(coalesce(group.count,
        max(
          length(coalesce(try(group.ipv4s, []), [])),
          length(coalesce(try(group.hostnames, []), []))
        )
        )) : {
        name        = try(group.hostnames[i], "${local.tenant == "" ? "" : "${local.tenant}-"}${var.cluster_name}-${var.purpose}-${i + 1}")
        server_type = group.type
        image       = group.image
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
