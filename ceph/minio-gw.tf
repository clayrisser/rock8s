module "nodes-minio-gw" {
  source              = "./modules/proxmox_vm"
  node_count          = var.vm_count
  proxmox_node        = var.proxmox_node
  ssh_public_keys_b64 = var.ssh_public_keys_b64
  vm_clone            = var.vm_clone
  vm_cpu_type         = var.vm_cpu_type
  vm_max_vcpus        = var.vm_max_vcpus
  vm_memory_mb        = var.vm_memory
  vm_name_prefix      = "minio-gw"
  vm_net_name         = var.vm_net_name
  vm_net_subnet_cidr  = var.vm_net_subnet_cidr
  vm_os_disk_size_gb  = var.vm_disk_size
  vm_os_disk_storage  = var.vm_os_disk_storage
  vm_sockets          = var.vm_sockets
  vm_tags             = "terraform;minio-gw"
  vm_user             = var.vm_user
  vm_vcpus            = var.vm_vcpus
}

locals {
  setup_script_content = templatefile(
    "${path.module}/scripts/setup-minio-gw.sh",
    {}
  )
}

resource "null_resource" "setup" {
  provisioner "file" {
    source      = "${path.module}/stacks/minio-gw/compose.yaml"
    destination = "/home/admin/stacks/minio-gw/compose.yaml"
    connection {
      host        = module.nodes-minio-gw.vm_list[0].ip0
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.vm_user
    }
  }
  provisioner "remote-exec" {
    inline = [
      "${local.setup_script_content}"
    ]
    connection {
      host        = module.nodes-minio-gw.vm_list[0].ip0
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.vm_user
    }
  }
  triggers = {
    always_run = timestamp()
  }
}
