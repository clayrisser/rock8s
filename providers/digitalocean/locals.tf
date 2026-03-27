locals {
  cluster     = var.cluster_name
  gateway_ip  = try(var.network.gateway, "")
  has_gateway = local.gateway_ip != ""

  network_lan = {
    name   = "${var.cluster_name}-lan"
    subnet = var.network.lan.ipv4.subnet
    zone   = var.location
  }

  vpc_inbound_cidrs = compact(concat(
    [local.network_lan.subnet],
    try(var.network.lan.ipv6.subnet, null) != null ? [var.network.lan.ipv6.subnet] : []
  ))

  firewall_ids = digitalocean_firewall.default[*].id
  firewall_id  = length(local.firewall_ids) > 0 ? local.firewall_ids[0] : null
  network = merge(
    { lan = local.network_lan },
    local.firewall_id != null ? { firewall_id = local.firewall_id } : {}
  )

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
  - systemctl restart networking
  - |
    IFACE=""
    while [ -z "$IFACE" ]; do
      IFACE=$(ip link show | grep -E "^[0-9]" | grep -vE "eth0|lo" | head -n1 | cut -d':' -f2 | tr -d ' ')
      if [ -z "$IFACE" ]; then
        sleep 10
        systemctl restart networking
      fi
    done
    echo "auto $IFACE" > /etc/network/interfaces.d/60-lan
    echo "iface $IFACE inet dhcp" >> /etc/network/interfaces.d/60-lan
    echo "  mtu ${try(var.network.lan.mtu, 1450)}" >> /etc/network/interfaces.d/60-lan
%{if local.has_gateway~}
    echo "  up route add default gw ${local.gateway_ip}" >> /etc/network/interfaces.d/60-lan
%{endif~}
    echo "  dns-nameservers 185.12.64.2 185.12.64.1" >> /etc/network/interfaces.d/60-lan
  - systemctl restart networking
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
        arch        = "amd64"
      }
    ]
  ])

  node_public_ipv4s = {
    for d in digitalocean_droplet.nodes :
    d.name => d.ipv4_address
  }
  node_private_ipv4s = {
    for d in digitalocean_droplet.nodes :
    d.name => d.ipv4_address_private
  }
  node_architectures = {
    for cfg in local.node_configs :
    cfg.name => cfg.arch
  }
}
