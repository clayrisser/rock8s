resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "node" {
  name       = "${local.cluster}-${var.purpose}"
  public_key = tls_private_key.node.public_key_openssh
}

resource "hcloud_network" "lan" {
  count             = var.purpose == "master" ? 1 : 0
  name              = local.network.lan.name
  ip_range          = local.network.lan.subnet
  delete_protection = true
}

data "hcloud_network" "lan" {
  count = var.purpose == "worker" ? 1 : 0
  name  = local.network.lan.name
}

resource "hcloud_network_subnet" "lan" {
  count        = var.purpose == "master" ? 1 : 0
  network_id   = hcloud_network.lan[0].id
  type         = "server"
  network_zone = local.network.lan.zone
  ip_range     = local.network.lan.subnet
}

resource "hcloud_network_route" "default" {
  count       = var.purpose == "master" && local.has_gateway ? 1 : 0
  network_id  = hcloud_network.lan[0].id
  destination = "0.0.0.0/0"
  gateway     = local.gateway_ip
  depends_on  = [hcloud_network_subnet.lan]
}

resource "hcloud_placement_group" "nodes" {
  name = "${local.cluster}-${var.purpose}"
  type = "spread"
  labels = {
    cluster = var.cluster_name
    purpose = var.purpose
  }
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
  labels = {
    cluster = var.cluster_name
  }
}

data "hcloud_firewall" "default" {
  count = var.purpose == "worker" ? 1 : 0
  name  = local.cluster
}

resource "hcloud_server" "nodes" {
  count              = length(local.node_configs)
  name               = local.node_configs[count.index].name
  server_type        = local.node_configs[count.index].server_type
  image              = coalesce(local.node_configs[count.index].image, var.image)
  location           = var.location
  ssh_keys           = [hcloud_ssh_key.node.id]
  user_data          = local.cloud_init
  delete_protection  = true
  rebuild_protection = true
  backups            = true
  placement_group_id = hcloud_placement_group.nodes.id
  firewall_ids       = var.purpose == "master" ? [hcloud_firewall.default[0].id] : [data.hcloud_firewall.default[0].id]
  labels = {
    cluster = var.cluster_name
    purpose = var.purpose
  }
  public_net {
    ipv4_enabled = !local.has_gateway
    ipv6_enabled = try(var.network.lan.ipv6, null) != null
  }
  network {
    network_id = var.purpose == "master" ? hcloud_network.lan[0].id : data.hcloud_network.lan[0].id
    ip         = local.node_configs[count.index].ipv4
  }
  lifecycle {
    ignore_changes = [
      image,
      network,
      rescue,
      user_data
    ]
  }
  depends_on = [hcloud_network_subnet.lan]
}
