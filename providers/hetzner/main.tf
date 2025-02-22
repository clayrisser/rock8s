resource "hcloud_ssh_key" "node" {
  name       = "${var.cluster_name}-${var.purpose}"
  public_key = file(var.ssh_public_key_path)
}

data "hcloud_network" "network" {
  name = var.network_name
}

resource "hcloud_server" "nodes" {
  count       = length(local.node_configs)
  name        = local.node_configs[count.index].name
  server_type = local.node_configs[count.index].server_type
  image       = try(local.node_configs[count.index].options.image, var.server_image)
  iso         = var.purpose == "pfsense" ? var.pfsense_iso : null
  location    = try(local.node_configs[count.index].options.location, var.location)
  ssh_keys    = [hcloud_ssh_key.node.id]
  user_data   = var.user_data != "" ? var.user_data : null
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
