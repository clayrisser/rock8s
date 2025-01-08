#!/bin/sh

PROXMOX_VERSION=8.2-2
PROXMOX_ISO="http://download.proxmox.com/iso/proxmox-ve_${PROXMOX_VERSION}.iso"
DRIVE_PREFIX="nvme"
SUDO=
if which sudo >/dev/null 2>&1; then
    SUDO=sudo
fi
$SUDO true
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update
$SUDO apt-get install -y \
    curl \
    ovmf \
    qemu-system-x86
if [ ! -f pve.iso ]; then
    curl -Lo pve.iso "$PROXMOX_ISO"
fi
DRIVES="$(lsblk -dn -o NAME | grep -E "^$DRIVE_PREFIX" | sort | head -n2)"
DRIVE_ARGS=""
for DRIVE in $DRIVES; do
    DRIVE_ARGS="$DRIVE_ARGS -drive file=/dev/$DRIVE,format=raw,if=virtio"
done
qemu-system-x86_64 \
    -enable-kvm \
    -machine type=q35,accel=kvm \
    -bios /usr/share/ovmf/OVMF.fd \
    -k en-us -cpu host -smp 4 -m 4096 -boot d -cdrom ./pve.iso \
    -global driver=cfi.pflash01,property=secure,value=on \
    -global ICH9-LPC.disable_s3=1 \
    -global ICH9-LPC.disable_s4=1 \
    -boot menu=on,strict=on \
    -device virtio-vga \
    -device intel-hda \
    -device virtio-net-pci \
    $DRIVE_ARGS \
    -vnc :0
