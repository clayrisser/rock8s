locals {
  master_groups = [
    for group in split(" ", var.masters) : {
      type  = split(":", group)[0]
      count = tonumber(split(":", group)[1])
    }
  ]
  worker_groups = [
    for group in split(" ", var.workers) : {
      type  = split(":", group)[0]
      count = tonumber(split(":", group)[1])
    }
  ]
  node_configs = concat(
    flatten([
      for group in local.master_groups : [
        for i in range(group.count) : {
          name        = "${var.cluster_name}-master-${i + 1}"
          server_type = group.type
          is_master   = true
        }
      ]
    ]),
    flatten([
      for idx, group in local.worker_groups : [
        for i in range(group.count) : {
          name        = "${var.cluster_name}-worker-${sum([for g in slice(local.worker_groups, 0, idx) : g.count]) + i + 1}"
          server_type = group.type
          is_master   = false
        }
      ]
    ])
  )
  master_ips = [
    for idx, server in hcloud_server.nodes :
    server.ipv4_address
    if local.node_configs[idx].is_master
  ]
  worker_ips = [
    for idx, server in hcloud_server.nodes :
    server.ipv4_address
    if !local.node_configs[idx].is_master
  ]
}
