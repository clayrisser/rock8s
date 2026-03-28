locals {
  cluster = var.cluster_name

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
    b2-7   = "amd64"
    b2-15  = "amd64"
    b2-30  = "amd64"
    b2-60  = "amd64"
    b2-120 = "amd64"
    c2-7   = "amd64"
    c2-15  = "amd64"
    c2-30  = "amd64"
    c2-60  = "amd64"
    d2-2   = "amd64"
    d2-4   = "amd64"
    d2-8   = "amd64"
  }

  lan_network_id = data.openstack_networking_network_v2.lan.id

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

  external_network_id = data.openstack_networking_network_v2.external.id

  node_public_ipv4s = {
    for idx, inst in openstack_compute_instance_v2.nodes :
    local.node_configs[idx].name => coalesce(
      inst.access_ip_v4,
      try([for n in inst.network : n.fixed_ip_v4 if n.uuid == local.external_network_id][0], ""),
      ""
    )
  }

  node_private_ipv4s = {
    for idx, inst in openstack_compute_instance_v2.nodes :
    local.node_configs[idx].name => coalesce(
      try([for n in inst.network : n.fixed_ip_v4 if n.uuid == local.lan_network_id][0], null),
      try(openstack_networking_port_v2.nodes[idx].all_fixed_ips[0], ""),
      ""
    )
  }

  node_architectures = {
    for cfg in local.node_configs :
    cfg.name => cfg.arch
  }
}
