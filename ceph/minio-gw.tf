module "nodes-minio-gw" {
  source              = "../modules/vm"
  instances           = var.instances
  node                = var.proxmox_node
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  clone               = var.clone
  cpu_type            = var.cpu_type
  max_vcpus           = var.max_vcpus
  memory              = var.memory
  prefix              = "minio-gw"
  net_name            = var.net_name
  net_subnet_cidr     = var.net_subnet_cidr
  os_disk_size        = var.disk_size
  os_disk_storage     = var.os_disk_storage
  sockets             = var.sockets
  tags                = "terraform;minio_gw"
  user                = var.user
  vcpus               = var.vcpus
}

locals {
  setup_script_content = templatefile(
    "${path.module}/scripts/setup-minio-gw.sh",
    {}
  )
}

resource "null_resource" "setup" {
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/admin/stacks/minio-gw"
    ]
    connection {
      host        = module.nodes-minio-gw.list[0].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  provisioner "file" {
    source      = "${path.module}/stacks/minio-gw/compose.yaml"
    destination = "/home/admin/stacks/minio-gw/compose.yaml"
    connection {
      host        = module.nodes-minio-gw.list[0].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  provisioner "remote-exec" {
    inline = [
      "${local.setup_script_content}"
    ]
    connection {
      host        = module.nodes-minio-gw.list[0].ip
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.user
    }
  }
  triggers = {
    always_run = timestamp()
  }
}
