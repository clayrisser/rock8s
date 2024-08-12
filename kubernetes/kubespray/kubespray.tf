locals {
  kubespray_inventory_content = templatefile(
    "${path.module}/artifacts/inventory.ini",
    {
      bastion      = "",
      cp_nodes     = join("\n", [for host in module.k8s_control_plane_nodes.list : join("", [host.name, " ansible_ssh_host=${host.ip}", " ansible_connection=ssh"])])
      worker_nodes = join("\n", [for host in module.k8s_worker_nodes.list : join("", [host.name, " ansible_ssh_host=${host.ip}", " ansible_connection=ssh"])]),
    }
  )
  kubespray_k8s_config_content = templatefile(
    "${path.module}/artifacts/k8s-cluster.yaml",
    {
      cluster_name                        = local.cluster_fqdn
      enable_nodelocaldns                 = var.enable_nodelocaldns
      ip_range                            = var.ip_range
      kube_network_plugin                 = var.kube_network_plugin
      kube_version                        = var.kube_version
      persistent_volumes_enabled          = var.persistent_volumes_enabled
      podsecuritypolicy_enabled           = var.podsecuritypolicy_enabled
      supplementary_addresses_in_ssl_keys = jsonencode(compact(split(",", var.public_ips)))
    }
  )
  kubespray_addon_config_content = templatefile(
    "${path.module}/artifacts/addons.yaml",
    {
      helm_enabled          = var.helm_enabled
      ingress_nginx_enabled = var.ingress_nginx_enabled
      argocd_enabled        = var.argocd_enabled
      argocd_version        = var.argocd_version
    }
  )
}

resource "null_resource" "setup_kubespray" {
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF > ${var.app_dir}/kubespray/inventory/sample/inventory.ini
      ${local.kubespray_inventory_content}
      EOF
      cat <<EOF > ${var.app_dir}/kubespray/inventory/sample/group_vars/k8s_cluster/k8s-cluster.yml
      ${local.kubespray_k8s_config_content}
      EOF
      cat <<EOF > ${var.app_dir}/kubespray/inventory/sample/group_vars/k8s_cluster/addons.yml
      ${local.kubespray_addon_config_content}
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
