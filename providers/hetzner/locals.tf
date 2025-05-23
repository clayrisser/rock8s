locals {
  cluster              = local.tenant == "" ? var.cluster_name : "${local.tenant}-${var.cluster_name}"
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
    sync = var.purpose == "pfsense" && try(var.network.sync.ipv4.subnet, "") != "" ? {
      name   = local.tenant == "" ? "${var.cluster_name}-sync" : "${local.tenant}-${var.cluster_name}-sync"
      subnet = var.network.sync.ipv4.subnet
      zone   = lookup(local.location_zones, var.location, "eu-central")
    } : null
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
  node_public_ipv4s = {
    for idx, server in hcloud_server.nodes :
    server.name => server.ipv4_address
  }
  node_private_ipv4s = {
    for idx, server in hcloud_server.nodes :
    server.name => coalesce(
      try([for net in server.network : net.ip if net.network_id == (
        var.purpose == "pfsense" ? hcloud_network.lan[0].id : data.hcloud_network.lan[0].id
      )][0], null),
      tolist(server.network)[0].ip
    )
  }
  lan_network_parts = var.purpose == "pfsense" ? split("/", var.network.lan.ipv4.subnet) : []
  lan_network_base  = length(local.lan_network_parts) > 0 ? split(".", local.lan_network_parts[0]) : []
  pfsense_lan_primary_ip = var.purpose == "pfsense" && length(local.lan_network_base) == 4 ? format("%s.%s.%s.2",
    local.lan_network_base[0], local.lan_network_base[1],
    local.lan_network_base[2]
  ) : null
  pfsense_lan_secondary_ip = (
    var.purpose == "pfsense" &&
    length(local.lan_network_base) == 4 &&
    length(local.node_configs) > 1
    ) ? format("%s.%s.%s.3",
    local.lan_network_base[0], local.lan_network_base[1],
    local.lan_network_base[2]
  ) : null
  node_sync_ipv4s = var.purpose == "pfsense" && local.network.sync != null ? {
    for idx, server in hcloud_server.nodes :
    server.name => coalesce(
      try([for net in server.network : net.ip if net.network_id == hcloud_network.sync[0].id][0], null),
      idx == 0 ? local.pfsense_sync_primary_ip : local.pfsense_sync_secondary_ip
    )
  } : {}
  sync_network_parts = var.purpose == "pfsense" && local.network.sync != null ? split("/", local.network.sync.subnet) : []
  sync_network_base  = length(local.sync_network_parts) > 0 ? split(".", local.sync_network_parts[0]) : []
  pfsense_sync_primary_ip = (
    var.purpose == "pfsense" &&
    local.network.sync != null &&
    length(local.sync_network_base) == 4
    ) ? format("%s.%s.%s.2",
    local.sync_network_base[0], local.sync_network_base[1],
    local.sync_network_base[2]
  ) : null
  pfsense_sync_secondary_ip = (
    var.purpose == "pfsense" &&
    local.network.sync != null &&
    length(local.sync_network_base) == 4 &&
    length(local.node_configs) > 1
    ) ? format("%s.%s.%s.3",
    local.sync_network_base[0], local.sync_network_base[1],
    local.sync_network_base[2]
  ) : null
}
