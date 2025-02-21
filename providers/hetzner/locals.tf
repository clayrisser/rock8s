locals {
  master_dir             = "${var.cluster_dir}/master"
  worker_dir             = "${var.cluster_dir}/worker"
  master_ssh_private_key = "${local.master_dir}/id_rsa"
  master_ssh_public_key  = "${local.master_dir}/id_rsa.pub"
  worker_ssh_private_key = "${local.worker_dir}/id_rsa"
  worker_ssh_public_key  = "${local.worker_dir}/id_rsa.pub"
  env_output             = "${var.cluster_dir}/.env.output"
  node_configs = flatten([
    [
      for group in var.master_groups : [
        for i in range(group.count) : {
          name        = "${var.cluster_name}-master-${i + 1}"
          server_type = group.type
          is_master   = true
          options     = group.options
        }
      ]
    ],
    [
      for idx, group in var.worker_groups : [
        for i in range(group.count) : {
          name        = "${var.cluster_name}-worker-${sum([for g in slice(var.worker_groups, 0, idx) : g.count]) + i + 1}"
          server_type = group.type
          is_master   = false
          options     = group.options
        }
      ]
    ]
  ])
  master_ips = {
    for idx, server in hcloud_server.nodes :
    server.name => server.ipv4_address
    if local.node_configs[idx].is_master
  }
  worker_ips = {
    for idx, server in hcloud_server.nodes :
    server.name => server.ipv4_address
    if !local.node_configs[idx].is_master
  }
  master_private_ips = {
    for idx, server in hcloud_server.nodes :
    server.name => server.network[0].ip
    if local.node_configs[idx].is_master
  }
  worker_private_ips = {
    for idx, server in hcloud_server.nodes :
    server.name => server.network[0].ip
    if !local.node_configs[idx].is_master
  }
}
