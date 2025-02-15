resource "null_resource" "create_kubespray_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.provider_dir}/kubespray/inventory/cluster/group_vars/{all,k8s_cluster}"
  }
}

resource "local_file" "kubespray_inventory" {
  content    = local.kubespray_inventory_content
  filename   = "${local.provider_dir}/kubespray/inventory/cluster/inventory.ini"
  depends_on = [null_resource.create_kubespray_dirs]
}

resource "local_file" "kubespray_all" {
  content    = local.kubespray_all_yml
  filename   = "${local.provider_dir}/kubespray/inventory/cluster/group_vars/all/all.yml"
  depends_on = [null_resource.create_kubespray_dirs]
}

resource "local_file" "kubespray_k8s_cluster" {
  content    = local.kubespray_k8s_cluster_yml
  filename   = "${local.provider_dir}/kubespray/inventory/cluster/group_vars/k8s_cluster/k8s-cluster.yml"
  depends_on = [null_resource.create_kubespray_dirs]
}

resource "local_file" "kubespray_addons" {
  content    = local.kubespray_addons_yml
  filename   = "${local.provider_dir}/kubespray/inventory/cluster/group_vars/k8s_cluster/addons.yml"
  depends_on = [null_resource.create_kubespray_dirs]
}

resource "local_file" "kubespray_calico" {
  content    = local.kubespray_k8s_net_calico_yml
  filename   = "${local.provider_dir}/kubespray/inventory/cluster/group_vars/k8s_cluster/k8s-net-calico.yml"
  depends_on = [null_resource.create_kubespray_dirs]
}
