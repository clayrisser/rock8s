#!/bin/sh

PROXMOX_VERSION=8.1-2
PROXMOX_ISO="http://download.proxmox.com/iso/proxmox-ve_${PROXMOX_VERSION}.iso"
DRIVE_INTERFACE="nvme"
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
DRIVES="$(lsblk -dn -o NAME | grep "$DRIVE_INTERFACE" | sort)"
DRIVE_ARGS=""
for DRIVE in $DRIVES; do
    DRIVE_ARGS="$DRIVE_ARGS -drive file=/dev/$DRIVE,format=raw,media=disk,if=virtio"
done
qemu-system-x86_64 -enable-kvm -bios /usr/share/ovmf/OVMF.fd \
    -k en-us -cpu host -smp 4 -m 4096 -boot d -cdrom ./pve.iso \
    $DRIVE_ARGS \
    -vnc :0
