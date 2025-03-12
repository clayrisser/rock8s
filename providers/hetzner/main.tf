resource "hcloud_ssh_key" "node" {
  name       = local.tenant == "" ? "${var.cluster_name}-${var.purpose}" : "${local.tenant}-${var.cluster_name}-${var.purpose}"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_network" "lan" {
  count             = var.purpose == "pfsense" ? 1 : 0
  name              = local.network.lan.name
  ip_range          = local.network.lan.subnet
  delete_protection = true
}

resource "hcloud_network" "sync" {
  count             = var.purpose == "pfsense" && local.network.sync != null ? 1 : 0
  name              = local.network.sync.name
  ip_range          = local.network.sync.subnet
  delete_protection = true
}

data "hcloud_network" "lan" {
  count = var.purpose != "pfsense" ? 1 : 0
  name  = local.network.lan.name
}

resource "hcloud_network_subnet" "lan" {
  count        = var.purpose == "pfsense" ? 1 : 0
  network_id   = hcloud_network.lan[0].id
  type         = "server"
  network_zone = local.network.lan.zone
  ip_range     = local.network.lan.subnet
}

resource "hcloud_network_route" "default" {
  count       = var.purpose == "pfsense" ? 1 : 0
  network_id  = hcloud_network.lan[0].id
  destination = "0.0.0.0/0"
  gateway     = local.pfsense_primary_ip
  depends_on  = [hcloud_network_subnet.lan]
}

resource "hcloud_server" "nodes" {
  count              = length(local.node_configs)
  name               = local.node_configs[count.index].name
  server_type        = local.node_configs[count.index].server_type
  image              = coalesce(local.node_configs[count.index].image, var.image)
  iso                = var.purpose == "pfsense" ? var.pfsense_iso : null
  location           = var.location
  ssh_keys           = [hcloud_ssh_key.node.id]
  user_data          = var.user_data != "" ? var.user_data : null
  delete_protection  = var.purpose != "worker"
  rebuild_protection = var.purpose != "worker"
  labels = merge(
    {
      cluster = var.cluster_name
      purpose = var.purpose
    },
    local.tenant != "" ? { tenant = local.tenant } : {}
  )
  network {
    network_id = var.purpose == "pfsense" ? hcloud_network.lan[0].id : data.hcloud_network.lan[0].id
    ip         = var.purpose == "pfsense" ? (count.index == 0 ? local.pfsense_primary_ip : local.pfsense_secondary_ip) : local.node_configs[count.index].ipv4
  }
  lifecycle {
    ignore_changes = [
      image,
      iso,
      network,
      rescue
    ]
  }
  depends_on = [hcloud_network_subnet.lan]
}
