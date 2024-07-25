terraform {
  required_version = ">=1.3.3"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc3"
    }
  }
}

resource "proxmox_vm_qemu" "vm" {
  count            = var.count_per_node * length(var.nodes)
  target_node      = var.nodes[count.index / var.count_per_node]
  clone            = var.clone
  qemu_os          = "l26"
  name             = "${var.prefix}-${format("%02d", count.index + 1)}"
  agent            = 1
  onboot           = var.onboot
  os_type          = "cloud-init"
  cores            = var.max_vcpus
  vcpus            = var.vcpus
  sockets          = var.sockets
  cpu              = var.cpu_type
  memory           = var.memory
  bootdisk         = "virtio0"
  scsihw           = "virtio-scsi-single"
  hotplug          = "network,disk,usb,memory,cpu"
  numa             = true
  automatic_reboot = true
  tags             = var.tags
  disks {
    scsi {
      scsi0 {
        disk {
          storage  = var.os_disk_storage
          size     = "${var.os_disk_size}G"
          iothread = true
        }
      }
    }
    ide {
      ide0 {
        cloudinit {
          storage = var.os_disk_storage
        }
      }
      ide2 {
        cdrom {}
      }
    }
  }
  network {
    model  = "virtio"
    bridge = var.network_bridge
    mtu    = 1400
  }
  ipconfig0 = "ip=dhcp${var.ipv6 ? ",ip6=dhcp" : ""}"
  ciuser    = var.user
  sshkeys   = base64decode(var.ssh_public_keys_b64)
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
