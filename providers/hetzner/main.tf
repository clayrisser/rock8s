resource "hcloud_ssh_key" "node" {
  name       = "${local.cluster}-${var.purpose}"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_network" "lan" {
  count             = var.purpose == "pfsense" ? 1 : 0
  name              = local.network.lan.name
  ip_range          = local.network.lan.subnet
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

resource "hcloud_network" "sync" {
  count             = var.purpose == "pfsense" && local.network.sync != null ? 1 : 0
  name              = local.network.sync.name
  ip_range          = local.network.sync.subnet
  delete_protection = true
}

data "hcloud_network" "sync" {
  count = var.purpose == "pfsense" && local.network.sync != null ? 1 : 0
  name  = local.network.sync.name
}

resource "hcloud_network_subnet" "sync" {
  count        = var.purpose == "pfsense" && local.network.sync != null ? 1 : 0
  network_id   = hcloud_network.sync[0].id
  type         = "server"
  network_zone = local.network.sync.zone
  ip_range     = local.network.sync.subnet
}

resource "hcloud_network_route" "default" {
  count       = var.purpose == "pfsense" ? 1 : 0
  network_id  = hcloud_network.lan[0].id
  destination = "0.0.0.0/0"
  gateway     = local.pfsense_lan_primary_ip
  depends_on  = [hcloud_network_subnet.lan]
}

resource "hcloud_placement_group" "nodes" {
  name = "${local.cluster}-${var.purpose}"
  type = "spread"
  labels = merge(
    {
      cluster = var.cluster_name
      purpose = var.purpose
    },
    local.tenant != "" ? { tenant = local.tenant } : {}
  )
}

resource "hcloud_firewall" "default" {
  count = var.purpose == "master" ? 1 : 0
  name  = local.cluster
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction       = "out"
    protocol        = "gre"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction       = "out"
    protocol        = "esp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
  labels = merge(
    {
      cluster = var.cluster_name
    },
    local.tenant != "" ? { tenant = local.tenant } : {}
  )
}

data "hcloud_firewall" "default" {
  count = var.purpose != "pfsense" && var.purpose != "master" ? 1 : 0
  name  = local.cluster
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
  delete_protection  = true
  rebuild_protection = true
  backups            = true
  placement_group_id = hcloud_placement_group.nodes.id
  firewall_ids = var.purpose == "pfsense" ? [] : (
    var.purpose == "master" ? [hcloud_firewall.default[0].id] : [data.hcloud_firewall.default[0].id]
  )
  labels = merge(
    {
      cluster = var.cluster_name
      purpose = var.purpose
    },
    local.tenant != "" ? { tenant = local.tenant } : {}
  )
  public_net {
    ipv4_enabled = try(var.network.lan.ipv4.nat, false) == false || var.purpose == "pfsense"
    ipv6_enabled = try(var.network.lan.ipv6, null) != null || var.purpose == "pfsense"
  }
  network {
    network_id = var.purpose == "pfsense" ? hcloud_network.lan[0].id : data.hcloud_network.lan[0].id
    ip         = var.purpose == "pfsense" ? (count.index == 0 ? local.pfsense_lan_primary_ip : local.pfsense_lan_secondary_ip) : local.node_configs[count.index].ipv4
  }
  dynamic "network" {
    for_each = var.purpose == "pfsense" && local.network.sync != null ? [1] : []
    content {
      network_id = hcloud_network.sync[0].id
      ip         = count.index == 0 ? local.pfsense_sync_primary_ip : local.pfsense_sync_secondary_ip
    }
  }
  lifecycle {
    ignore_changes = [
      image,
      iso,
      network,
      rescue,
      user_data
    ]
  }
  depends_on = [hcloud_network_subnet.lan, hcloud_network_subnet.sync]
}
