packer {
  required_plugins {
    qemu = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "pfsense_version" {
  type    = string
  default = "2.7.2"
}

variable "iso_url" {
  type    = string
  default = ""
}

variable "iso_checksum" {
  type    = string
  default = ""
}

variable "disk_size" {
  type    = string
  default = "20480"
}

variable "memory" {
  type    = string
  default = "4096"
}

variable "cpus" {
  type    = string
  default = "4"
}

variable "headless" {
  type    = bool
  default = true
}

variable "arch" {
  type    = string
  default = "amd64"
  validation {
    condition     = contains(["amd64"], var.arch)
    error_message = "only amd64 is currently supported for pfSense images"
  }
}

locals {
  iso_filename = "pfSense-CE-${var.pfsense_version}-RELEASE-${var.arch}.iso"
  build_id     = "pfsense-${var.pfsense_version}-${var.arch}-{{timestamp}}"
  qemu_binary  = var.arch == "amd64" ? "qemu-system-x86_64" : "qemu-system-aarch64"
  machine_type = var.arch == "amd64" ? "pc" : "virt"
}

source "qemu" "pfsense" {
  accelerator      = "kvm"
  boot_command     = [
    "<wait40>",
    "<enter><wait2>",
    "<enter><wait2>",
    "<enter><wait2>",
    "<enter><wait2>",
    "<enter><wait2>",
    " <wait2>",
    "<enter><wait2>",
    "<tab><wait2>",
    "<enter><wait120>",
    "<enter><wait90>",
    "n<enter><wait2>",
    "vtnet0<enter><wait2>",
    "vtnet1<enter><wait2>",
    "y<enter><wait60>",
    "14<enter><wait2>",
    "y<enter><wait10>",
    "8<enter><wait2>",
    "echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config<enter><wait2>",
    "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config<enter><wait2>",
    "echo 'pfsense' | pw usermod root -h 0<enter><wait2>",
    "service sshd restart<enter><wait5>",
    "pfctl -d<enter><wait2>",
    "dhclient vtnet0<enter><wait5>",
    "exit<enter>",
  ]
  boot_wait        = "20s"
  cpus             = var.cpus
  disk_interface   = "virtio"
  disk_size        = var.disk_size
  format           = "qcow2"
  headless         = var.headless
  iso_checksum     = var.iso_checksum != "" ? var.iso_checksum : "none"
  iso_url          = var.iso_url != "" ? var.iso_url : "file://${path.cwd}/.build/${local.iso_filename}"
  memory           = var.memory
  net_device       = "virtio-net"
  output_directory = "${path.cwd}/.build/output-pfsense"
  shutdown_command = "shutdown -p now"
  ssh_password     = "pfsense"
  ssh_timeout      = "60m"
  ssh_username     = "root"
  ssh_wait_timeout = "60m"
  vm_name          = "pfsense"
  qemuargs = [
    ["-netdev", "user,id=user.0,hostfwd=tcp::{{ .SSHHostPort }}-:22,hostfwd=tcp::10443-:443,net=10.0.2.0/24,dhcpstart=10.0.2.15"],
    ["-device", "virtio-net-pci,netdev=user.0,mac=52:54:00:12:34:01"],
    ["-netdev", "user,id=user.1,net=10.0.3.0/24,dhcpstart=10.0.3.15"],
    ["-device", "virtio-net-pci,netdev=user.1,mac=52:54:00:12:34:02"],
    ["-netdev", "user,id=user.2,net=10.0.4.0/24,dhcpstart=10.0.4.15"],
    ["-device", "virtio-net-pci,netdev=user.2,mac=52:54:00:12:34:03"],
    ["-netdev", "user,id=user.3,net=10.0.5.0/24,dhcpstart=10.0.5.15"],
    ["-device", "virtio-net-pci,netdev=user.3,mac=52:54:00:12:34:04"]
  ]
}

build {
  sources = ["source.qemu.pfsense"]

  provisioner "file" {
    source      = "${path.root}/scripts/provision.sh"
    destination = "/tmp/provision.sh"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/initialize.sh"
    destination = "/tmp/initialize.sh"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/initialize.php"
    destination = "/tmp/initialize.php"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/startup.sh"
    destination = "/tmp/startup.sh"
  }

  provisioner "shell-local" {
    command = "sh ${path.root}/scripts/local.sh"
  }

  provisioner "shell" {
    execute_command = "{{ .Path }}"
    expect_disconnect = true
    inline = [
      "sh /tmp/provision.sh",
      "rm -f /tmp/initialize.php",
      "rm -f /tmp/initialize.sh",
      "rm -f /tmp/provision.sh",
      "rm -f /tmp/startup.sh"
    ]
  }
}
