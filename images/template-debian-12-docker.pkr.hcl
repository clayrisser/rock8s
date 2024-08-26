source "proxmox-iso" "template-debian-12-docker" {
  bios                     = "seabios"
  boot_command             = ["<esc><wait>auto url=http://${var.network_ip}:{{ .HTTPPort }}/preseed.cfg<enter>"]
  boot_wait                = "10s"
  cloud_init               = true
  cloud_init_storage_pool  = var.storage_pool
  cores                    = var.cores
  cpu_type                 = var.cpu
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
  vm_name                  = "template-debian-12-docker"
  network_adapters {
    bridge   = var.network_bridge
    firewall = true
    model    = "virtio"
    mtu      = 1400
  }
  disks {
    disk_size    = var.disk_size
    format       = var.disk_format
    storage_pool = var.storage_pool
    type         = "scsi"
  }
}

build {
  sources = ["source.proxmox-iso.template-debian-12-docker"]
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
  provisioner "shell" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "sudo apt-get update",
      "sudo apt-get install -y ca-certificates curl",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      <<EOF
sudo apt-get install -y \
    containerd.io \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin
EOF
    ]
  }
  provisioner "file" {
    destination = "/etc/cloud/cloud.cfg"
    source      = "docker/cloud.cfg"
  }
  provisioner "file" {
    destination = "/etc/cloud/cloud.cfg.d/99-pve.cfg"
    source      = "http/99-pve.cfg"
  }
}
