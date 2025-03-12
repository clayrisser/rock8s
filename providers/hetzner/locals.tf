locals {
  tenant               = var.tenant == "" || var.tenant == null || var.tenant == "default" ? "" : var.tenant
  node_ssh_private_key = "${var.cluster_dir}/${var.purpose}/id_rsa"
  location_zones = {
    "nbg1" = "eu-central"
    "fsn1" = "eu-central"
    "hel1" = "eu-central"
    "ash"  = "us-east"
    "hil"  = "us-east"
  }
  network = {
    lan = {
      name   = local.tenant == "" ? "${var.cluster_name}-lan" : "${local.tenant}-${var.cluster_name}-lan"
      subnet = var.network.lan.ipv4.subnet
      zone   = lookup(local.location_zones, var.location, "eu-central")
    }
  }
  node_configs = flatten([
    for group in var.nodes : [
      for i in range(
        max(
          coalesce(group.count, 0),
          length(coalesce(try(group.ipv4s, []), [])),
          length(coalesce(try(group.hostnames, []), [])),
          1
        )
        ) : {
        name        = "${local.tenant == "" ? "" : "${local.tenant}-"}${var.cluster_name}-${var.purpose}-${i + 1}"
        server_type = group.type
        image       = group.image
        ipv4        = try(group.ipv4s[i], null)
      }
    ]
  ])
  node_public_ips = {
    for idx, server in hcloud_server.nodes :
    server.name => server.ipv4_address
  }
  node_private_ips = {
    for idx, server in hcloud_server.nodes :
    server.name => one(server.network).ip
  }
  network_parts = var.purpose == "pfsense" ? split("/", var.network.lan.ipv4.subnet) : []
  network_base  = length(local.network_parts) > 0 ? split(".", local.network_parts[0]) : []
  pfsense_primary_ip = var.purpose == "pfsense" && length(local.network_base) == 4 ? format("%s.%s.%s.2",
    local.network_base[0], local.network_base[1],
    local.network_base[2]
  ) : null
  pfsense_secondary_ip = (
    var.purpose == "pfsense" &&
    length(local.network_base) == 4 &&
    length(local.node_configs) > 1
    ) ? format("%s.%s.%s.3",
    local.network_base[0], local.network_base[1],
    local.network_base[2]
  ) : null
}
