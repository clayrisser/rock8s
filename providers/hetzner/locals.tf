locals {
  cluster = local.tenant == "" ? var.cluster_name : "${local.tenant}-${var.cluster_name}"
  tenant  = var.tenant == "" || var.tenant == null || var.tenant == "default" ? "" : var.tenant
  gateway_parts  = var.purpose != "pfsense" ? split("/", var.network.lan.ipv4.subnet) : []
  gateway_octets = length(local.gateway_parts) > 0 ? split(".", local.gateway_parts[0]) : []
  gateway_ip = length(local.gateway_octets) == 4 ? format("%s.%s.%s.2",
    local.gateway_octets[0], local.gateway_octets[1], local.gateway_octets[2]
  ) : ""
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
    echo "  mtu 1450" >> /etc/network/interfaces.d/60-lan
    echo "  up route add default gw ${local.gateway_ip}" >> /etc/network/interfaces.d/60-lan
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
  arch_map = {
    cpx11 = "amd64"
    cpx21 = "amd64"
    cpx31 = "amd64"
    cpx41 = "amd64"
    cpx51 = "amd64"
    cax11 = "arm64"
    cax21 = "arm64"
    cax31 = "arm64"
    cax41 = "arm64"
    ccx13 = "amd64"
    ccx23 = "amd64"
    ccx33 = "amd64"
    ccx43 = "amd64"
    ccx53 = "amd64"
    ccx63 = "amd64"
    cx22  = "amd64"
    cx32  = "amd64"
    cx42  = "amd64"
    cx52  = "amd64"
  }
  location_zones = {
    "nbg1" = "eu-central"
    "fsn1" = "eu-central"
    "hel1" = "eu-central"
    "ash"  = "us-east"
    "hil"  = "us-east"
  }
  network = {
    lan = {
      name   = local.tenant == "" ? "${var.cluster_name}-lan" : "${local.tenant}-${var.cluster_name}-lan"
      subnet = var.network.lan.ipv4.subnet
      zone   = lookup(local.location_zones, var.location, "eu-central")
    }
    sync = var.purpose == "pfsense" && try(var.network.sync.ipv4.subnet, "") != "" ? {
      name   = local.tenant == "" ? "${var.cluster_name}-sync" : "${local.tenant}-${var.cluster_name}-sync"
      subnet = var.network.sync.ipv4.subnet
      zone   = lookup(local.location_zones, var.location, "eu-central")
    } : null
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
        name        = "${local.tenant == "" ? "" : "${local.tenant}-"}${var.cluster_name}-${var.purpose}-${i + 1}"
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
      try([for net in server.network : net.ip if net.network_id == (
        var.purpose == "pfsense" ? hcloud_network.lan[0].id : data.hcloud_network.lan[0].id
      )][0], null),
      tolist(server.network)[0].ip
    )
  }
  lan_network_parts = var.purpose == "pfsense" ? split("/", var.network.lan.ipv4.subnet) : []
  lan_network_base  = length(local.lan_network_parts) > 0 ? split(".", local.lan_network_parts[0]) : []
  pfsense_lan_primary_ip = var.purpose == "pfsense" && length(local.lan_network_base) == 4 ? format("%s.%s.%s.2",
    local.lan_network_base[0], local.lan_network_base[1],
    local.lan_network_base[2]
  ) : null
  pfsense_lan_secondary_ip = (
    var.purpose == "pfsense" &&
    length(local.lan_network_base) == 4 &&
    length(local.node_configs) > 1
    ) ? format("%s.%s.%s.3",
    local.lan_network_base[0], local.lan_network_base[1],
    local.lan_network_base[2]
  ) : null
  node_sync_ipv4s = var.purpose == "pfsense" && local.network.sync != null ? {
    for idx, server in hcloud_server.nodes :
    server.name => coalesce(
      try([for net in server.network : net.ip if net.network_id == hcloud_network.sync[0].id][0], null),
      idx == 0 ? local.pfsense_sync_primary_ip : local.pfsense_sync_secondary_ip
    )
  } : {}
  sync_network_parts = var.purpose == "pfsense" && local.network.sync != null ? split("/", local.network.sync.subnet) : []
  sync_network_base  = length(local.sync_network_parts) > 0 ? split(".", local.sync_network_parts[0]) : []
  pfsense_sync_primary_ip = (
    var.purpose == "pfsense" &&
    local.network.sync != null &&
    length(local.sync_network_base) == 4
    ) ? format("%s.%s.%s.2",
    local.sync_network_base[0], local.sync_network_base[1],
    local.sync_network_base[2]
  ) : null
  pfsense_sync_secondary_ip = (
    var.purpose == "pfsense" &&
    local.network.sync != null &&
    length(local.sync_network_base) == 4 &&
    length(local.node_configs) > 1
    ) ? format("%s.%s.%s.3",
    local.sync_network_base[0], local.sync_network_base[1],
    local.sync_network_base[2]
  ) : null
  node_architectures = {
    for idx, cfg in local.node_configs :
    cfg.name => cfg.arch
  }
}
