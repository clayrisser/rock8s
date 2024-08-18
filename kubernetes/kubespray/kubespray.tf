locals {
  cluster_name = "${var.cluster_prefix}-${var.iteration}"
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
      cluster_name                        = local.cluster_name
      kube_version                        = var.kube_version
      supplementary_addresses_in_ssl_keys = length(split(",", var.public_ips)) > 1 ? jsonencode(compact(split(",", var.public_ips))) : "[]"
    }
  )
  kubespray_addons_yml = templatefile(
    "${path.module}/artifacts/addons.yml", {
      ip_range                            = var.ip_range
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
