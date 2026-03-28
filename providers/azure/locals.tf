locals {
  cluster     = var.cluster_name
  gateway_ip  = try(var.network.gateway, "")
  has_gateway = local.gateway_ip != ""

  # Marketplace images (align with var.image validation).
  azure_image = {
    "debian-12" = {
      publisher = "Debian"
      offer     = "debian-12"
      sku       = "12-gen2"
      version   = "latest"
    }
    "debian-11" = {
      publisher = "Debian"
      offer     = "debian-11"
      sku       = "11-gen2"
      version   = "latest"
    }
    "ubuntu-22.04" = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    "ubuntu-20.04" = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-focal"
      sku       = "20_04-lts-gen2"
      version   = "latest"
    }
    "centos-7" = {
      publisher = "OpenLogic"
      offer     = "CentOS"
      sku       = "7_9-gen2"
      version   = "latest"
    }
    "rocky-9" = {
      publisher = "resf"
      offer     = "rockylinux-x86_64"
      sku       = "9-base-gen2"
      version   = "latest"
    }
    "fedora-37" = {
      publisher = "fedora-cloud"
      offer     = "fedora-cloud"
      sku       = "37-cloudbase-gen2"
      version   = "latest"
    }
  }

  cloud_init = <<-EOT
#cloud-config
users:
  - name: rock8s
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
  - apt-get update || true
package_update: true
package_upgrade: true
packages:
  - nfs-common
  - open-iscsi
EOT

  # Standard_D*ps_v5 SKUs use Azure Ampere (ARM64); all others listed are x64.
  arch_map = {
    Standard_B2s     = "amd64"
    Standard_B4ms    = "amd64"
    Standard_D2s_v5  = "amd64"
    Standard_D4s_v5  = "amd64"
    Standard_D8s_v5  = "amd64"
    Standard_D2ps_v5 = "arm64"
    Standard_D4ps_v5 = "arm64"
    Standard_E2s_v5  = "amd64"
    Standard_E4s_v5  = "amd64"
    Standard_F2s_v2  = "amd64"
    Standard_F4s_v2  = "amd64"
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

  common_tags = {
    cluster = var.cluster_name
    purpose = var.purpose
  }

  rg_name = var.purpose == "master" ? azurerm_resource_group.cluster[0].name : data.azurerm_resource_group.cluster[0].name

  subnet_id = data.azurerm_subnet.lan.id

  node_private_ipv4s = {
    for idx, nic in azurerm_network_interface.nodes :
    local.node_configs[idx].name => nic.private_ip_address
  }

  node_public_ipv4s = {
    for idx, vm in azurerm_linux_virtual_machine.nodes :
    local.node_configs[idx].name => coalesce(vm.public_ip_address, "")
  }

  node_architectures = {
    for idx, cfg in local.node_configs :
    cfg.name => cfg.arch
  }
}
