locals {
  cluster    = var.cluster_name
  cloud_init = <<-EOT
#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - ${tls_private_key.node.public_key_openssh}
env:
  PATH: /usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/games:/usr/games
write_files:
  - path: /etc/sysctl.d/99-k8s.conf
    content: |
      fs.file-max=262144
bootcmd:
  - modprobe dm_thin_pool
  - modprobe dm_snapshot
  - modprobe dm_mirror
  - modprobe dm_crypt
  - sysctl -p /etc/sysctl.d/99-k8s.conf
runcmd:
  - systemctl enable iscsid
  - systemctl start iscsid
  - apt-get update
package_update: true
package_upgrade: true
packages:
  - nfs-common
  - open-iscsi
EOT
  arch_map = {
    cx23  = "amd64"
    cx33  = "amd64"
    cx43  = "amd64"
    cx53  = "amd64"
    cpx22 = "amd64"
    cpx32 = "amd64"
    cpx42 = "amd64"
    cpx52 = "amd64"
    cpx62 = "amd64"
    ccx13 = "amd64"
    ccx23 = "amd64"
    ccx33 = "amd64"
    ccx43 = "amd64"
    ccx53 = "amd64"
    ccx63 = "amd64"
  }
  node_configs = flatten([
    for group in var.nodes : [
      for i in range(
        max(
          coalesce(group.count, 0),
          length(coalesce(try(group.ipv4s, []), [])),
          length(coalesce(try(group.hostnames, []), [])),
          1
        )
        ) : {
        name        = "${var.cluster_name}-${var.purpose}-${i + 1}"
        server_type = group.type
        image       = group.image
        ipv4        = try(group.ipv4s[i], null)
        arch        = lookup(local.arch_map, group.type, "amd64")
      }
    ]
  ])
  node_public_ipv4s = {
    for idx, server in hcloud_server.nodes :
    server.name => server.ipv4_address
  }
  node_private_ipv4s = {
    for idx, server in hcloud_server.nodes :
    server.name => coalesce(
      try([for net in server.network : net.ip if net.network_id == data.hcloud_network.lan.id][0], null),
      tolist(server.network)[0].ip
    )
  }
  node_architectures = {
    for idx, cfg in local.node_configs :
    cfg.name => cfg.arch
  }
}
