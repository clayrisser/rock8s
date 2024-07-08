locals {
  kubespray_data_dir = "$HOME/kubespray"
  setup_kubespray_script_content = templatefile(
    "${path.module}/scripts/setup_kubespray.sh",
    {
      kubespray_data_dir = local.kubespray_data_dir
    }
  )
  install_kubernetes_script_content = templatefile(
    "${path.module}/scripts/install_kubernetes.sh",
    {
      kubespray_data_dir = local.kubespray_data_dir,
    }
  )
  kubespray_inventory_content = templatefile(
    "${path.module}/kubespray/inventory.ini",
    {
      bastion      = "",
      cp_nodes     = join("\n", [for host in module.k8s_control_plane_nodes.vm_list : join("", [host.name, " ansible_ssh_host=${host.ip0}", " ansible_connection=ssh"])])
      worker_nodes = join("\n", [for host in module.k8s_worker_nodes.vm_list : join("", [host.name, " ansible_ssh_host=${host.ip0}", " ansible_connection=ssh"])]),
    }
  )
  kubespray_k8s_config_content = templatefile(
    "${path.module}/kubespray/k8s-cluster.yaml",
    {
      kube_version               = var.kube_version
      kube_network_plugin        = var.kube_network_plugin
      cluster_name               = local.cluster_fqdn
      enable_nodelocaldns        = var.enable_nodelocaldns
      podsecuritypolicy_enabled  = var.podsecuritypolicy_enabled
      persistent_volumes_enabled = var.persistent_volumes_enabled
    }
  )
  kubespray_addon_config_content = templatefile(
    "${path.module}/kubespray/addons.yaml",
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
      ${local.setup_kubespray_script_content}
      cat <<EOF > ${local.kubespray_data_dir}/kubespray/inventory/sample/inventory.ini
      ${local.kubespray_inventory_content}
      EOF
      cat <<EOF > ${local.kubespray_data_dir}/kubespray/inventory/sample/group_vars/k8s_cluster/k8s-cluster.yml
      ${local.kubespray_k8s_config_content}
      EOF
      cat <<EOF > ${local.kubespray_data_dir}/kubespray/inventory/sample/group_vars/k8s_cluster/addons.yml
      ${local.kubespray_addon_config_content}
      EOF
      ${local.install_kubernetes_script_content}
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
