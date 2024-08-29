module "nodes-minio-gw" {
  source              = "../modules/vm"
  clone               = var.clone
  count_per_node      = 1
  cpu                 = var.cpu
  ipv6                = true
  memory              = var.memory
  network_bridge      = var.network_bridge
  nodes               = var.proxmox_nodes
  disk_size           = var.disk_size
  disk_storage        = var.disk_storage
  prefix              = "minio-gw"
  protection          = true
  sockets             = var.sockets
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  tags                = "terraform;minio_gw"
  user                = var.user
  vcpus               = var.vcpus
}

data "external" "proxmox_ips" {
  count = length(module.nodes-minio-gw.list)
  program = ["sh", "-c", <<EOF
    echo "{\"ip\": \"172.$(echo '${var.network_bridge}' | grep -oE '[0-9]+').0.$(echo '${var.proxmox_nodes[count.index]}' | grep -oE '[0-9]+' | awk '{print $1 + 10}')\"}"
  EOF
  ]
}

locals {
  setup_script_content = templatefile(
    "${path.module}/scripts/setup-minio-gw.sh",
    {}
  )
  proxmox_ips = [for proxmox_ip in data.external.proxmox_ips : proxmox_ip.result.ip]
}

resource "null_resource" "setup" {
  count = length(module.nodes-minio-gw.list)
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/admin/stacks/minio-gw"
    ]
    connection {
      host        = module.nodes-minio-gw.list[count.index].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  provisioner "file" {
    source      = "${path.module}/stacks/minio-gw/compose.yaml"
    destination = "/home/admin/stacks/minio-gw/compose.yaml"
    connection {
      host        = module.nodes-minio-gw.list[count.index].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  provisioner "remote-exec" {
    inline = [
      "export S3_ACCESS_KEY=\"${var.s3_access_key}\"",
      "export S3_SECRET_KEY=\"${var.s3_secret_key}\"",
      "export S3_ENDPOINT=\"http://${local.proxmox_ips[count.index]}:7480\"",
      "${local.setup_script_content}"
    ]
    connection {
      host        = module.nodes-minio-gw.list[count.index].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  triggers = {
    always_run = timestamp()
  }
}
