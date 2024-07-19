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
      host        = module.nodes.vm_list[0].ip0
      private_key = base64decode(var.ssh_private_key_b64)
      type        = "ssh"
      user        = var.vm_user
    }
  }
  triggers = {
    always_run = timestamp()
  }
  depends_on = [
    module.nodes
  ]
}
