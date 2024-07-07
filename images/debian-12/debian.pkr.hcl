packer {
  required_plugins {
    proxmox = {
      version = "1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "debian-12" {
  bios                     = "seabios"
  boot_command             = ["<esc><wait>auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"]
  boot_wait                = "10s"
  cloud_init               = true
  cloud_init_storage_pool  = var.storage_pool
  cores                    = var.cores
  cpu_type                 = var.cpu_type
  http_directory           = "http"
  http_port_max            = 8100
  http_port_min            = 8100
  insecure_skip_tls_verify = true
  iso_checksum             = var.iso_checksum
  iso_file                 = var.iso_file
  iso_storage_pool         = var.iso_storage_pool
  iso_url                  = var.iso_url
  machine                  = "q35"
  memory                   = var.memory
  node                     = var.proxmox_node
  os                       = "l26"
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  qemu_agent               = true
  scsi_controller          = "virtio-scsi-pci"
  sockets                  = "1"
  ssh_password             = "packer"
  ssh_timeout              = "60m"
  ssh_username             = "root"
  template_description     = "Debian 12 Bullseye Packer Template -- Created: ${formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())}"
  unmount_iso              = true
  username                 = var.proxmox_token_id
  token                    = var.proxmox_token_secret
  vm_name                  = var.vm_name
  network_adapters {
    bridge   = var.network_bridge
    firewall = true
    model    = "virtio"
  }
  disks {
    disk_size    = var.disk_size
    format       = var.disk_format
    storage_pool = var.storage_pool
    type         = "scsi"
  }
}

build {
  sources = ["source.proxmox-iso.debian-12"]
  provisioner "shell" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "apt-get update",
      <<EOF
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  cloud-init \
  curl \
  gnupg-agent \
  htop \
  linux-headers-amd64 \
  linux-image-amd64 \
  software-properties-common \
  sudo \
  unattended-upgrades \
  vim \
  wget
EOF
    ]
  }
  provisioner "file" {
    destination = "/etc/cloud/cloud.cfg"
    source      = "http/cloud.cfg"
  }
  provisioner "file" {
    destination = "/etc/cloud/cloud.cfg.d/99-pve.cfg"
    source      = "http/99-pve.cfg"
  }
}
