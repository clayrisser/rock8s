terraform {
  required_version = ">=1.3.3"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

resource "proxmox_vm_qemu" "vm" {
  count            = var.node_count > 0 ? var.node_count : (var.count_per_node * length(var.nodes))
  target_node      = var.nodes[count.index % length(var.nodes)]
  agent            = 1
  automatic_reboot = true
  balloon          = var.memory
  bios             = "seabios"
  bootdisk         = "virtio0"
  clone            = var.clone
  cores            = var.cores > 0 ? var.cores : var.vcpus
  cpu_type         = var.cpu
  hotplug          = "network,disk,usb"
  memory           = var.memory
  name             = "${var.prefix}-${format("%02d", count.index + 1)}"
  numa             = true
  onboot           = var.onboot
  os_type          = "cloud-init"
  protection       = var.protection
  qemu_os          = "l26"
  scsihw           = "virtio-scsi-single"
  sockets          = var.sockets
  tags             = replace(lower(var.tags), "/[^a-z0-9_;]/", "_")
  vcpus            = var.vcpus
  disks {
    scsi {
      scsi0 {
        disk {
          storage  = var.disk_storage
          size     = "${var.disk_size}G"
          iothread = true
          discard  = true
          cache    = "writethrough"
        }
      }
    }
    ide {
      ide0 {
        cloudinit {
          storage = var.disk_storage
        }
      }
      ide2 {
        cdrom {}
      }
    }
  }
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
    mtu    = 1400
  }
  vga {
    type = var.display
  }
  ipconfig0 = "ip=dhcp${var.ipv6 ? ",ip6=auto" : ""}"
  ciuser    = var.user
  sshkeys   = base64decode(var.ssh_public_keys_b64)
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
