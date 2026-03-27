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

resource "vultr_vpc2" "lan" {
  count         = var.purpose == "master" ? 1 : 0
  description   = local.vpc_description
  region        = local.vultr_region
  ip_type       = "v4"
  ip_block      = local.vpc_ip_block
  prefix_length = local.vpc_prefix
}

data "vultr_vpc2" "lan" {
  count = var.purpose == "worker" ? 1 : 0
  filter {
    name   = "description"
    values = [local.vpc_description]
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

resource "vultr_firewall_rule" "lan_tcp" {
  count             = var.purpose == "master" ? 1 : 0
  firewall_group_id = vultr_firewall_group.default[0].id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = local.vpc_ip_block
  subnet_size       = local.vpc_prefix
  port              = "1:65535"
}

resource "vultr_firewall_rule" "lan_udp" {
  count             = var.purpose == "master" ? 1 : 0
  firewall_group_id = vultr_firewall_group.default[0].id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = local.vpc_ip_block
  subnet_size       = local.vpc_prefix
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
  vpc2_ids          = [var.purpose == "master" ? vultr_vpc2.lan[0].id : data.vultr_vpc2.lan[0].id]
  lifecycle {
    ignore_changes = [
      os_id,
      user_data
    ]
  }
}
