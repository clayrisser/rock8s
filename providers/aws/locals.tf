locals {
  cluster = var.cluster_name

  # Instance type → arch for validated node types; Graviton *g families are arm64.
  arch_map = {
    "t3.medium"  = "amd64"
    "t3.large"   = "amd64"
    "t3.xlarge"  = "amd64"
    "m5.large"   = "amd64"
    "m5.xlarge"  = "amd64"
    "m5.2xlarge" = "amd64"
    "m6g.medium" = "arm64"
    "m6g.large"  = "arm64"
    "m6g.xlarge" = "arm64"
    "c5.large"   = "amd64"
    "c5.xlarge"  = "amd64"
    "c6g.large"  = "arm64"
    "c6g.xlarge" = "arm64"
    "r5.large"   = "amd64"
    "r5.xlarge"  = "amd64"
  }

  # Extra Graviton (and a1) families for arch if node types are expanded later.
  graviton_families = toset([
    "a1",
    "t4g",
    "m6g", "m7g", "m8g",
    "c6g", "c7g", "c8g",
    "r6g", "r7g", "r8g",
    "x2g",
    "i8g",
    "hpc6g", "hpc7g",
  ])

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
        arch = coalesce(
          lookup(local.arch_map, group.type, null),
          contains(local.graviton_families, split(".", group.type)[0]) ? "arm64" : "amd64"
        )
      }
    ]
  ])

  ami_lookup_keys = toset([
    for c in local.node_configs :
    "${replace(coalesce(c.image, var.image), ".", "-")}:${c.arch}"
  ])

  # Debian official (136693071363); Ubuntu (099720109477). Name patterns must match published AMIs.
  ami_profile_for = {
    "debian-11"    = { owners = ["136693071363"], name_tmpl = "debian-11-%s-*" }
    "debian-12"    = { owners = ["136693071363"], name_tmpl = "debian-12-%s-*" }
    "debian-13"    = { owners = ["136693071363"], name_tmpl = "debian-13-%s-*" }
    "ubuntu-20-04" = { owners = ["099720109477"], name_tmpl = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-%s-server-*" }
    "ubuntu-22-04" = { owners = ["099720109477"], name_tmpl = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-%s-server-*" }
    "ubuntu-24-04" = { owners = ["099720109477"], name_tmpl = "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-%s-server-*" }
    "ubuntu-25-10" = { owners = ["099720109477"], name_tmpl = "ubuntu/images/hvm-ssd-gp3/ubuntu-questing-25.10-%s-server-*" }
  }

  ami_name_for_key = {
    for k in local.ami_lookup_keys : k => format(
      local.ami_profile_for[split(":", k)[0]].name_tmpl,
      split(":", k)[1]
    )
  }

  ami_owners_for_key = {
    for k in local.ami_lookup_keys : k => local.ami_profile_for[split(":", k)[0]].owners
  }

  node_public_ipv4s = {
    for idx, inst in aws_instance.nodes :
    local.node_configs[idx].name => inst.public_ip
  }
  node_private_ipv4s = {
    for idx, inst in aws_instance.nodes :
    local.node_configs[idx].name => inst.private_ip
  }
  node_architectures = {
    for cfg in local.node_configs :
    cfg.name => cfg.arch
  }
}
