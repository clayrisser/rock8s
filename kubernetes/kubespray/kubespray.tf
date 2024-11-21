locals {
  kubespray_inventory_content = templatefile(
    "${path.module}/artifacts/inventory.ini",
    {
      bastion      = ""
      cp_nodes     = join("\n", [for host in module.k8s_control_plane_nodes.list : join("", [host.name, " ansible_ssh_host=${host.ip}", " ansible_connection=ssh"])])
      worker_nodes = join("\n", [for host in module.k8s_worker_nodes.list : join("", [host.name, " ansible_ssh_host=${host.ip}", " ansible_connection=ssh"])])
    }
  )
  kubespray_all_yml = templatefile(
    "${path.module}/artifacts/all.yml", {}
  )
  kubespray_k8s_cluster_yml = templatefile(
    "${path.module}/artifacts/k8s-cluster.yml",
    {
      kube_version                        = var.kube_version
      dualstack                           = var.dualstack
      supplementary_addresses_in_ssl_keys = jsonencode([var.cluster_entrypoint])
    }
  )
  kubespray_addons_yml = templatefile(
    "${path.module}/artifacts/addons.yml", {
      ip_range                  = var.ip_range
      ceph_provisioner_monitors = var.ceph_provisioner_monitors
      ceph_provisioner_admin_id = var.ceph_provisioner_admin_id
      ceph_provisioner_secret   = var.ceph_provisioner_secret
    }
  )
  kubespray_k8s_net_calico_yml = templatefile(
    "${path.module}/artifacts/k8s-net-calico.yml", {}
  )
}

resource "null_resource" "setup_kubespray" {
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF > ${var.app_dir}/kubespray/inventory/sample/inventory.ini
      ${local.kubespray_inventory_content}
      EOF
      cat <<EOF > ${var.app_dir}/kubespray/inventory/sample/group_vars/all/all.yml
      ${local.kubespray_all_yml}
      EOF
      cat <<EOF > ${var.app_dir}/kubespray/inventory/sample/group_vars/k8s_cluster/k8s-cluster.yml
      ${local.kubespray_k8s_cluster_yml}
      EOF
      cat <<EOF > ${var.app_dir}/kubespray/inventory/sample/group_vars/k8s_cluster/addons.yml
      ${local.kubespray_addons_yml}
      EOF
      cat <<EOF > ${var.app_dir}/kubespray/inventory/sample/group_vars/k8s_cluster/k8s-net-calico.yml
      ${local.kubespray_k8s_net_calico_yml}
      EOF
    EOT
  }
  triggers = {
    always_run = timestamp()
  }
  depends_on = [
    module.k8s_control_plane_nodes,
    module.k8s_worker_nodes
  ]
}
