module "nodes-minio-gw" {
  source              = "../modules/vm"
  clone               = var.clone
  count_per_node      = 1
  cpu_type            = var.cpu_type
  ipv6                = true
  max_vcpus           = var.max_vcpus
  memory              = var.memory
  network_bridge      = var.network_bridge
  nodes               = var.proxmox_nodes
  os_disk_size        = var.disk_size
  os_disk_storage     = var.os_disk_storage
  prefix              = "minio-gw"
  sockets             = var.sockets
  ssh_public_keys_b64 = var.ssh_public_keys_b64
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
      "export S3_ACCESS_KEY=\"${var.s3_access_key}\"",
      "export S3_SECRET_KEY=\"${var.s3_secret_key}\"",
      "export S3_ENDPOINT=\"${var.s3_endpoint}\"",
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
