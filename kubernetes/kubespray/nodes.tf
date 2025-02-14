locals {
  control_plane_nodes = {
    for idx, ip in var.master_ips : ip => {
      hostname = "master-${idx + 1}"
      ip       = ip
      role     = "master"
      user     = var.user
      port     = 22
    }
  }
  worker_nodes = {
    for idx, ip in var.worker_ips : ip => {
      hostname = "worker-${idx + 1}"
      ip       = ip
      role     = "worker"
      user     = var.user
      port     = 22
    }
  }
  nodes = merge(local.control_plane_nodes, local.worker_nodes)
  inventory = {
    all = {
      hosts = {
        for ip, node in local.nodes : node.hostname => {
          ansible_host = node.ip
          ip           = node.ip
          ansible_user = node.user
          ansible_port = node.port
        }
      }
      children = {
        kube_control_plane = {
          hosts = {
            for ip, node in local.control_plane_nodes : node.hostname => {}
          }
        }
        kube_node = {
          hosts = {
            for ip, node in local.nodes : node.hostname => {}
          }
        }
        etcd = {
          hosts = {
            for ip, node in local.control_plane_nodes : node.hostname => {}
          }
        }
        k8s_cluster = {
          children = {
            kube_control_plane = {}
            kube_node          = {}
          }
        }
      }
      vars = {
        ansible_ssh_private_key_file        = var.ssh_private_key
        supplementary_addresses_in_ssl_keys = values(local.control_plane_nodes)[*].ip
        kubernetes_version                  = var.kube_version
        kube_network_plugin                 = var.kube_network_plugin
        kube_pods_subnet                    = var.pod_network_cidr
        kube_service_addresses              = var.service_network_cidr
        container_manager                   = "containerd"
      }
    }
  }
}

resource "null_resource" "kubespray_prep" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOF
      git clone --depth 1 --branch ${var.kubespray_version} https://github.com/kubernetes-sigs/kubespray.git kubespray || true
      cd kubespray
      pip3 install -r requirements.txt
    EOF
  }
}

resource "local_file" "inventory" {
  content    = yamlencode(local.inventory)
  filename   = "${path.module}/inventory/vmk/hosts.yaml"
  depends_on = [null_resource.kubespray_prep]
}

resource "null_resource" "cluster_init" {
  count = length(local.control_plane_nodes) > 0 ? 1 : 0
  triggers = {
    inventory = local_file.inventory.content
  }
  provisioner "local-exec" {
    command = <<-EOF
      cd kubespray
      ansible-playbook -i inventory/vmk/hosts.yaml cluster.yml -b
    EOF
  }
  depends_on = [local_file.inventory]
}

resource "null_resource" "add_nodes" {
  for_each = {
    for ip, node in local.nodes : ip => node
    if node.status == "adding"
  }
  triggers = {
    node = each.key
  }
  provisioner "local-exec" {
    command = <<-EOF
      cd kubespray
      ansible-playbook -i inventory/vmk/hosts.yaml scale.yml -b --limit=${each.value.hostname}
    EOF
  }
  depends_on = [null_resource.cluster_init]
}

resource "null_resource" "remove_nodes" {
  for_each = {
    for ip, node in local.nodes : ip => node
    if node.status == "removing"
  }
  triggers = {
    node = each.key
  }
  provisioner "local-exec" {
    command = <<-EOF
      cd kubespray
      ansible-playbook -i inventory/vmk/hosts.yaml remove-node.yml -b -e node=${each.value.hostname}
    EOF
  }
  depends_on = [null_resource.cluster_init]
}

output "control_plane_nodes" {
  value = {
    for ip, node in local.control_plane_nodes : node.hostname => {
      ip = ip
    }
  }
}

output "worker_nodes" {
  value = {
    for ip, node in local.worker_nodes : node.hostname => {
      ip = ip
    }
  }
}
