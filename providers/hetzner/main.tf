resource "hcloud_ssh_key" "node" {
  name       = local.tenant == "" ? "${var.cluster_name}-${var.purpose}" : "${local.tenant}-${var.cluster_name}-${var.purpose}"
  public_key = file(var.ssh_public_key_path)
}

data "hcloud_network" "network" {
  name = var.network
}

resource "hcloud_server" "nodes" {
  count       = length(local.node_configs)
  name        = local.node_configs[count.index].name
  server_type = local.node_configs[count.index].server_type
  image       = try(local.node_configs[count.index].options.image, var.image)
  iso         = var.purpose == "pfsense" ? var.pfsense_iso : null
  location    = try(local.node_configs[count.index].options.location, var.location)
  ssh_keys    = [hcloud_ssh_key.node.id]
  user_data   = var.user_data != "" ? var.user_data : null
  labels = merge(
    {
      cluster = var.cluster_name
      purpose = var.purpose
    },
    local.tenant != "" ? { tenant = local.tenant } : {}
  )
  network {
    network_id = data.hcloud_network.network.id
    ip         = local.node_configs[count.index].ipv4
  }
  lifecycle {
    ignore_changes = [
      image,
      rescue,
      iso
    ]
  }
}
