resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "vultr_ssh_key" "node" {
  name    = "${local.cluster}-${var.purpose}"
  ssh_key = tls_private_key.node.public_key_openssh
}

data "vultr_os" "default" {
  filter {
    name   = "name"
    values = [local.os_name]
  }
}

data "vultr_vpc2" "lan" {
  filter {
    name   = "description"
    values = [var.network.lan.name]
  }
}

resource "vultr_firewall_group" "default" {
  count       = var.purpose == "master" ? 1 : 0
  description = local.firewall_description
}

data "vultr_firewall_group" "default" {
  count = var.purpose == "worker" ? 1 : 0
  filter {
    name   = "description"
    values = [local.firewall_description]
  }
}

resource "vultr_firewall_rule" "egress_tcp" {
  count             = var.purpose == "master" ? 1 : 0
  firewall_group_id = vultr_firewall_group.default[0].id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "1:65535"
}

resource "vultr_firewall_rule" "egress_udp" {
  count             = var.purpose == "master" ? 1 : 0
  firewall_group_id = vultr_firewall_group.default[0].id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "1:65535"
}

resource "vultr_firewall_rule" "egress_icmp" {
  count             = var.purpose == "master" ? 1 : 0
  firewall_group_id = vultr_firewall_group.default[0].id
  protocol          = "icmp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
}

resource "vultr_firewall_rule" "ssh_public" {
  count             = var.purpose == "master" ? 1 : 0
  firewall_group_id = vultr_firewall_group.default[0].id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "22"
}

resource "vultr_firewall_rule" "lan_tcp" {
  count             = var.purpose == "master" ? 1 : 0
  firewall_group_id = vultr_firewall_group.default[0].id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = data.vultr_vpc2.lan.ip_block
  subnet_size       = data.vultr_vpc2.lan.prefix
  port              = "1:65535"
}

resource "vultr_firewall_rule" "lan_udp" {
  count             = var.purpose == "master" ? 1 : 0
  firewall_group_id = vultr_firewall_group.default[0].id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = data.vultr_vpc2.lan.ip_block
  subnet_size       = data.vultr_vpc2.lan.prefix
  port              = "1:65535"
}

resource "vultr_instance" "nodes" {
  count             = length(local.node_configs)
  label             = local.node_configs[count.index].name
  hostname          = local.node_configs[count.index].name
  plan              = local.node_configs[count.index].server_type
  region            = local.vultr_region
  os_id             = data.vultr_os.default.id
  ssh_key_ids       = [vultr_ssh_key.node.id]
  firewall_group_id = var.purpose == "master" ? vultr_firewall_group.default[0].id : data.vultr_firewall_group.default[0].id
  user_data         = base64encode(local.cloud_init)
  backups           = "enabled"
  enable_ipv6       = try(var.network.lan.ipv6, null) != null
  tags              = [local.cluster, var.purpose]
  vpc2_ids          = [data.vultr_vpc2.lan.id]
  lifecycle {
    ignore_changes = [
      os_id,
      user_data
    ]
  }
}
