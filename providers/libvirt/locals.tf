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
  - util-linux
  - xfsprogs
EOT

  node_sizes = {
    "small"  = { vcpu = 1, memory = 2048, disk_gb = 20 }
    "medium" = { vcpu = 2, memory = 4096, disk_gb = 40 }
    "large"  = { vcpu = 4, memory = 8192, disk_gb = 80 }
    "xlarge" = { vcpu = 8, memory = 16384, disk_gb = 160 }
  }

  network = {
    lan = {
      name   = "${var.cluster_name}-lan"
      subnet = var.network.lan.ipv4.subnet
    }
  }

  lan_network_parts = split("/", var.network.lan.ipv4.subnet)
  lan_network_base  = split(".", local.lan_network_parts[0])

  # masters start at .10, workers at .100
  node_ip_offset = var.purpose == "master" ? 10 : 100

  _raw_node_configs = flatten([
    for group in var.nodes : [
      for i in range(
        max(
          coalesce(group.count, 0),
          length(coalesce(try(group.ipv4s, []), [])),
          length(coalesce(try(group.hostnames, []), [])),
          1
        )
        ) : {
        name = "${var.cluster_name}-${var.purpose}-${i + 1}"
        size = local.node_sizes[group.type]
        ipv4 = try(group.ipv4s[i], null)
      }
    ]
  ])

  node_configs = [
    for idx, config in local._raw_node_configs : merge(config, {
      ipv4 = coalesce(config.ipv4, format("%s.%s.%s.%d",
        local.lan_network_base[0], local.lan_network_base[1],
        local.lan_network_base[2], local.node_ip_offset + idx
      ))
    })
  ]

  node_private_ipv4s = {
    for idx, domain in libvirt_domain.nodes :
    local.node_configs[idx].name => local.node_configs[idx].ipv4
  }

  node_public_ipv4s = local.node_private_ipv4s
}
