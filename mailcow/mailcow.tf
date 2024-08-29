module "nodes" {
  source              = "../modules/vm"
  clone               = var.clone
  cpu                 = var.cpu
  ipv6                = true
  memory              = var.memory
  network_bridge      = var.network_bridge
  node_count          = 1
  nodes               = var.proxmox_nodes
  disk_size           = var.disk_size
  disk_storage        = var.disk_storage
  prefix              = "mailcow"
  protection          = true
  sockets             = var.sockets
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  tags                = "terraform;mailcow"
  user                = var.user
  vcpus               = var.vcpus
}

data "external" "proxmox_ips" {
  count = length(module.nodes.list)
  program = ["sh", "-c", <<EOF
    echo "{\"ip\": \"172.$(echo '${var.network_bridge}' | grep -oE '[0-9]+').0.$(echo '${var.proxmox_nodes[count.index]}' | grep -oE '[0-9]+' | awk '{print $1 + 10}')\"}"
  EOF
  ]
}

locals {
  setup_script_content = templatefile(
    "${path.module}/scripts/setup.sh",
    {}
  )
  proxmox_ips = [for proxmox_ip in data.external.proxmox_ips : proxmox_ip.result.ip]
}

resource "null_resource" "setup" {
  count = length(module.nodes.list)
  provisioner "remote-exec" {
    inline = [
      "export MAIL_HOSTNAME=${var.mail_hostname}",
      "${local.setup_script_content}"
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
