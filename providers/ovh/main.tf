data "openstack_networking_network_v2" "external" {
  name = "Ext-Net"
}

resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "node" {
  name       = "${local.cluster}-${var.purpose}-rock8s"
  public_key = tls_private_key.node.public_key_openssh
}

data "openstack_networking_network_v2" "lan" {
  name = var.network.lan.name
}

data "openstack_networking_subnet_v2" "lan" {
  network_id = data.openstack_networking_network_v2.lan.id
}

resource "openstack_networking_secgroup_v2" "nodes" {
  count       = var.purpose == "master" ? 1 : 0
  name        = "${local.cluster}-nodes"
  description = "rock8s ${var.cluster_name} nodes (${var.purpose})"
  tags        = [var.cluster_name, var.purpose]
}

data "openstack_networking_secgroup_v2" "nodes" {
  count = var.purpose == "worker" ? 1 : 0
  name  = "${local.cluster}-nodes"
}

resource "openstack_networking_secgroup_rule_v2" "egress_tcp" {
  count             = var.purpose == "master" ? 1 : 0
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_secgroup_rule_v2" "egress_udp" {
  count             = var.purpose == "master" ? 1 : 0
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_secgroup_rule_v2" "egress_icmp" {
  count             = var.purpose == "master" ? 1 : 0
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_secgroup_rule_v2" "egress_gre" {
  count             = var.purpose == "master" ? 1 : 0
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "gre"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_secgroup_rule_v2" "egress_esp" {
  count             = var.purpose == "master" ? 1 : 0
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "esp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_lan_tcp" {
  count             = var.purpose == "master" ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_group_id   = openstack_networking_secgroup_v2.nodes[0].id
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_lan_udp" {
  count             = var.purpose == "master" ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_group_id   = openstack_networking_secgroup_v2.nodes[0].id
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_lan_icmp" {
  count             = var.purpose == "master" ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.nodes[0].id
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_ssh" {
  count             = var.purpose == "master" && !local.has_gateway ? 1 : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nodes[0].id
}

resource "openstack_networking_port_v2" "nodes" {
  count              = length(local.node_configs)
  name               = "${local.node_configs[count.index].name}-lan"
  network_id         = local.lan_network_id
  admin_state_up     = true
  security_group_ids = var.purpose == "master" ? [openstack_networking_secgroup_v2.nodes[0].id] : [data.openstack_networking_secgroup_v2.nodes[0].id]
  tags               = [var.cluster_name, var.purpose, local.node_configs[count.index].name]

  dynamic "fixed_ip" {
    for_each = local.node_configs[count.index].ipv4 != null ? [1] : []
    content {
      subnet_id  = data.openstack_networking_subnet_v2.lan.id
      ip_address = local.node_configs[count.index].ipv4
    }
  }
}

resource "openstack_compute_instance_v2" "nodes" {
  count           = length(local.node_configs)
  name            = local.node_configs[count.index].name
  flavor_name     = local.node_configs[count.index].server_type
  image_name      = coalesce(local.node_configs[count.index].image, var.image)
  key_pair        = openstack_compute_keypair_v2.node.name
  security_groups = []
  user_data       = local.cloud_init
  metadata = {
    cluster = var.cluster_name
    purpose = var.purpose
    role    = var.purpose
  }

  network {
    port = openstack_networking_port_v2.nodes[count.index].id
  }

  network {
    uuid = data.openstack_networking_network_v2.external.id
  }

  lifecycle {
    ignore_changes = [
      image_name,
      image_id,
      network,
      user_data,
    ]
  }

  depends_on = [
    openstack_networking_port_v2.nodes,
  ]
}
