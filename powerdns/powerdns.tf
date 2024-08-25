module "nodes" {
  source              = "../modules/vm"
  clone               = var.clone
  cpu                 = var.cpu
  ipv6                = true
  memory              = var.memory
  network_bridge      = var.network_bridge
  node_count          = var.node_count
  nodes               = var.proxmox_nodes
  os_disk_size        = var.disk_size
  os_disk_storage     = var.os_disk_storage
  prefix              = "powerdns"
  protection          = var.protection
  sockets             = var.sockets
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  tags                = "terraform;powerdns"
  user                = var.user
  vcpus               = var.vcpus
}

locals {
  setup_script_content = templatefile(
    "${path.module}/scripts/setup.sh",
    {
      nameservers = var.nameservers
      primary_ip = module.nodes.list[0].ip
      secondary_ips = join(",", [for i, node in module.nodes.list : node.ip if i != 0])
    }
  )
}

resource "null_resource" "setup" {
  count = length(module.nodes.list)
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/admin/stacks/powerdnsadmin"
    ]
    connection {
      host        = module.nodes.list[count.index].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  provisioner "file" {
    source      = "${path.module}/stacks/powerdnsadmin/compose.yaml"
    destination = "/home/admin/stacks/powerdnsadmin/compose.yaml"
    connection {
      host        = module.nodes.list[count.index].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  provisioner "remote-exec" {
    inline = [
      "NODE_INDEX=${count.index}",
      "${local.setup_script_content}",
    ]
    connection {
      host        = module.nodes.list[count.index].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  triggers = {
    always_run = timestamp()
  }
}

output "nodes" {
  value = module.nodes.list
}
