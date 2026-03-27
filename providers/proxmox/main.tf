resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "proxmox_virtual_environment_download_file" "cloud_image" {
  content_type = "iso"
  datastore_id = var.content_datastore_id
  node_name    = var.proxmox_node
  url          = var.image
  file_name    = "${local.cluster}-${var.purpose}-cloud.img"

  overwrite           = false
  overwrite_unmanaged = false
}

resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = var.content_datastore_id
  node_name    = var.proxmox_node

  source_raw {
    data      = local.cloud_init
    file_name = "${local.cluster}-${var.purpose}-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "nodes" {
  count = length(local.node_configs)

  name      = local.node_configs[count.index].name
  node_name = var.proxmox_node

  on_boot = true
  started = true

  agent {
    enabled = true
  }

  cpu {
    cores = local.node_configs[count.index].size.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = local.node_configs[count.index].size.memory
  }

  disk {
    datastore_id = var.datastore_id
    import_from  = proxmox_virtual_environment_download_file.cloud_image.id
    interface    = "virtio0"
    size         = local.node_configs[count.index].size.disk_gb
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.node_configs[count.index].ipv4}/${local.lan_prefix_length}"
        gateway = local.has_gateway ? local.gateway_ip : format("%s.%s.%s.1",
          local.lan_network_base[0], local.lan_network_base[1],
          local.lan_network_base[2]
        )
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  network_device {
    bridge = var.bridge
  }

  lifecycle {
    ignore_changes = [
      initialization,
      disk[0].import_from,
    ]
  }
}
