locals {
  cluster     = var.cluster_name
  gateway_ip  = try(var.network.gateway, "")
  has_gateway = local.gateway_ip != ""
  zone        = "${var.location}-b"

  vpc_name    = "${var.cluster_name}-lan"
  subnet_name = "${var.cluster_name}-lan-subnet"
  node_tags   = ["${var.cluster_name}-node"]

  cloud_init = <<-EOT
#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - ${chomp(tls_private_key.node.public_key_openssh)}
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
    "e2-medium"      = "amd64"
    "e2-standard-2"  = "amd64"
    "e2-standard-4"  = "amd64"
    "e2-standard-8"  = "amd64"
    "n2-standard-2"  = "amd64"
    "n2-standard-4"  = "amd64"
    "n2-standard-8"  = "amd64"
    "n2d-standard-2" = "amd64"
    "n2d-standard-4" = "amd64"
    "t2a-standard-1" = "arm64"
    "t2a-standard-2" = "arm64"
    "t2a-standard-4" = "arm64"
    "c3-standard-4"  = "amd64"
  }

  image_map = {
    "debian-12"    = "debian-cloud/debian-12"
    "debian-11"    = "debian-cloud/debian-11"
    "ubuntu-22.04" = "ubuntu-os-cloud/ubuntu-2204-lts"
    "ubuntu-20.04" = "ubuntu-os-cloud/ubuntu-2004-lts"
    "centos-7"     = "centos-cloud/centos-7"
    "rocky-9"      = "rocky-linux-cloud/rocky-linux-9"
    "fedora-37"    = "fedora-cloud/fedora-37"
  }

  network = {
    lan = {
      name   = local.vpc_name
      subnet = var.network.lan.ipv4.subnet
      zone   = local.zone
    }
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
        name         = "${var.cluster_name}-${var.purpose}-${i + 1}"
        machine_type = group.type
        network_ip   = try(group.ipv4s[i], null)
        arch         = lookup(local.arch_map, group.type, "amd64")
        boot_image = lookup(
          local.image_map,
          coalesce(group.image, var.image),
          local.image_map[var.image]
        )
      }
    ]
  ])

  node_public_ipv4s = {
    for inst in google_compute_instance.nodes :
    inst.name => try(inst.network_interface[0].access_config[0].nat_ip, "")
  }

  node_private_ipv4s = {
    for inst in google_compute_instance.nodes :
    inst.name => inst.network_interface[0].network_ip
  }

  node_architectures = {
    for cfg in local.node_configs :
    cfg.name => cfg.arch
  }
}
