locals {
  cluster     = var.cluster_name
  gateway_ip  = try(var.network.gateway, "")
  has_gateway = local.gateway_ip != ""

  # Vultr OS list names must match exactly one entry (data.vultr_os).
  os_map = {
    "debian-12"    = "Debian 12 x64 (bookworm)"
    "debian-11"    = "Debian 11 x64 (bullseye)"
    "ubuntu-22.04" = "Ubuntu 22.04 LTS x64"
    "ubuntu-20.04" = "Ubuntu 20.04 LTS x64"
    "rocky-9"      = "Rocky Linux x64 9"
    "fedora-37"    = "Fedora 37 x64"
  }

  os_name = lookup(local.os_map, var.image, var.image)

  # Region slug doubles as the Vultr API region identifier.
  region_map = {
    ewr = "ewr"
    ord = "ord"
    dfw = "dfw"
    sea = "sea"
    lax = "lax"
    ams = "ams"
    fra = "fra"
    lhr = "lhr"
    sgp = "sgp"
    nrt = "nrt"
    syd = "syd"
  }

  vultr_region = lookup(local.region_map, var.location, var.location)

  vpc_cidr_parts = split("/", var.network.lan.ipv4.subnet)
  vpc_ip_block   = cidrhost(var.network.lan.ipv4.subnet, 0)
  vpc_prefix     = tonumber(local.vpc_cidr_parts[1])

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
    echo "  dns-nameservers 108.61.10.10 1.1.1.1" >> /etc/network/interfaces.d/60-lan
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
    vc2-1c-2gb       = "amd64"
    vc2-2c-4gb       = "amd64"
    vc2-4c-8gb       = "amd64"
    vc2-6c-16gb      = "amd64"
    vc2-8c-32gb      = "amd64"
    vhp-1c-2gb-amd   = "amd64"
    vhp-2c-4gb-amd   = "amd64"
    vhp-4c-8gb-amd   = "amd64"
    vhp-1c-2gb-intel = "amd64"
    vhp-2c-4gb-intel = "amd64"
  }

  network = {
    lan = {
      name   = "${var.cluster_name}-lan"
      subnet = var.network.lan.ipv4.subnet
      zone   = local.vultr_region
    }
  }

  vpc_description      = local.network.lan.name
  firewall_description = "${local.cluster}-firewall"

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
    for idx, inst in vultr_instance.nodes :
    local.node_configs[idx].name => inst.main_ip
  }

  node_private_ipv4s = {
    for idx, inst in vultr_instance.nodes :
    local.node_configs[idx].name => inst.internal_ip
  }

  node_architectures = {
    for cfg in local.node_configs :
    cfg.name => cfg.arch
  }
}
