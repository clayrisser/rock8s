locals {
  setup_script_content = templatefile(
    "${path.module}/scripts/setup.sh",
    {}
  )
}

resource "null_resource" "setup" {
  provisioner "remote-exec" {
    inline = [
      "${local.setup_script_content}"
    ]
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = base64decode(var.ssh_private_key_b64)
      host        = module.nodes[0].public_ip
    }
  }
  triggers = {
    always_run = timestamp()
  }
  depends_on = [
    module.k8s_control_plane_nodes,
    module.k8s_worker_nodes
  ]
}
