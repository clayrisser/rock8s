resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "digitalocean_ssh_key" "node" {
  name       = "${local.cluster}-${var.purpose}"
  public_key = tls_private_key.node.public_key_openssh
}

data "digitalocean_vpc" "lan" {
  name = var.network.lan.name
}

resource "digitalocean_firewall" "default" {
  count = var.purpose == "master" ? 1 : 0
  name  = local.cluster

  inbound_rule {
    protocol    = "tcp"
    port_range  = "1-65535"
    source_tags = [local.cluster]
  }

  inbound_rule {
    protocol    = "udp"
    port_range  = "1-65535"
    source_tags = [local.cluster]
  }

  inbound_rule {
    protocol    = "icmp"
    source_tags = [local.cluster]
  }

  dynamic "inbound_rule" {
    for_each = local.has_gateway ? [] : [1]
    content {
      protocol         = "tcp"
      port_range       = "22"
      source_addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  tags = [local.cluster]
}

resource "digitalocean_droplet" "nodes" {
  count = length(local.node_configs)

  name      = local.node_configs[count.index].name
  region    = var.location
  size      = local.node_configs[count.index].server_type
  image     = coalesce(local.node_configs[count.index].image, var.image)
  vpc_uuid  = data.digitalocean_vpc.lan.id
  ssh_keys  = [digitalocean_ssh_key.node.id]
  user_data = local.cloud_init
  backups   = true
  ipv6      = try(var.network.lan.ipv6, null) != null

  tags = [local.cluster, var.purpose]

  lifecycle {
    ignore_changes = [
      image,
      user_data
    ]
  }

  depends_on = [
    digitalocean_firewall.default
  ]
}
