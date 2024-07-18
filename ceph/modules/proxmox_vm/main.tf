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
  count            = var.node_count
  target_node      = var.proxmox_node
  clone            = var.vm_clone
  qemu_os          = "l26"
  name             = "${var.vm_name_prefix}-${format("%02d", count.index + 1)}"
  agent            = 1
  onboot           = var.vm_onboot
  os_type          = "cloud-init"
  cores            = var.vm_max_vcpus
  vcpus            = var.vm_vcpus
  sockets          = var.vm_sockets
  cpu              = var.vm_cpu_type
  memory           = var.vm_memory_mb
  bootdisk         = "virtio0"
  scsihw           = "virtio-scsi-single"
  hotplug          = "network,disk,usb,memory,cpu"
  numa             = true
  automatic_reboot = true
  tags             = var.vm_tags
  disks {
    scsi {
      scsi0 {
        disk {
          storage  = var.vm_os_disk_storage
          size     = "${var.vm_os_disk_size_gb}G"
          iothread = true
        }
      }
    }
    ide {
      ide0 {
        cloudinit {
          storage = var.vm_os_disk_storage
        }
      }
      ide2 {
        cdrom {}
      }
    }
  }
  network {
    model  = "virtio"
    bridge = var.vm_net_name
  }
  ipconfig0 = "ip=dhcp"
  ciuser    = var.vm_user
  sshkeys   = base64decode(var.ssh_public_keys_b64)
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
