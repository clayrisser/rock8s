locals {
  cluster = var.cluster_name

  # Vultr OS list names must match exactly one entry (data.vultr_os).
  os_map = {
    "debian-13"    = "Debian 13 x64 (trixie)"
    "debian-12"    = "Debian 12 x64 (bookworm)"
    "debian-11"    = "Debian 11 x64 (bullseye)"
    "ubuntu-25.10" = "Ubuntu 25.10 x64"
    "ubuntu-24.04" = "Ubuntu 24.04 LTS x64"
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
