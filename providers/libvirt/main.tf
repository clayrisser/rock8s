resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "libvirt_network" "lan" {
  count     = var.purpose == "master" ? 1 : 0
  name      = local.network.lan.name
  mode      = "nat"
  domain    = "${local.cluster}.local"
  addresses = [local.network.lan.subnet]
  autostart = true

  dhcp {
    enabled = true
  }

  dns {
    enabled = true
  }
}

resource "libvirt_volume" "base" {
  name   = "${local.cluster}-${var.purpose}-base.qcow2"
  pool   = var.pool
  source = var.image
  format = "qcow2"
}

resource "libvirt_volume" "nodes" {
  count          = length(local.node_configs)
  name           = "${local.node_configs[count.index].name}.qcow2"
  pool           = var.pool
  base_volume_id = libvirt_volume.base.id
  size           = local.node_configs[count.index].size.disk_gb * 1073741824
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "nodes" {
  count     = length(local.node_configs)
  name      = "${local.node_configs[count.index].name}-cloudinit.iso"
  pool      = var.pool
  user_data = local.cloud_init
  meta_data = <<-EOF
    instance-id: ${local.node_configs[count.index].name}
    local-hostname: ${local.node_configs[count.index].name}
  EOF
}

resource "libvirt_domain" "nodes" {
  count     = length(local.node_configs)
  name      = local.node_configs[count.index].name
  vcpu      = local.node_configs[count.index].size.vcpu
  memory    = local.node_configs[count.index].size.memory
  running   = true
  autostart = true
  firmware  = var.firmware != "" ? var.firmware : null
  arch      = var.arch != "" ? var.arch : null
  machine   = var.machine != "" ? var.machine : null

  cloudinit = libvirt_cloudinit_disk.nodes[count.index].id

  dynamic "cpu" {
    for_each = var.cpu_mode != "" ? [var.cpu_mode] : []
    content {
      mode = cpu.value
    }
  }

  disk {
    volume_id = libvirt_volume.nodes[count.index].id
  }

  network_interface {
    network_name   = local.network.lan.name
    addresses      = [local.node_configs[count.index].ipv4]
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  lifecycle {
    ignore_changes = [
      cloudinit
    ]
  }

  depends_on = [libvirt_network.lan]
}
