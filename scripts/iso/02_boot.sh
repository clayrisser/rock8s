#!/bin/sh

DRIVE_PREFIX="nvme"
DRIVES="$(lsblk -dn -o NAME | grep -E "^$DRIVE_PREFIX" | sort | head -n2)"
DRIVE_ARGS=""
for DRIVE in $DRIVES; do
    DRIVE_ARGS="$DRIVE_ARGS -drive file=/dev/$DRIVE,format=raw,media=disk,if=virtio"
done
qemu-system-x86_64 \
    -enable-kvm \
    -machine type=q35,accel=kvm \
    -bios /usr/share/ovmf/OVMF.fd \
    -k en-us -cpu host -smp 4 -m 4096 -boot d \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
    -device virtio-net,netdev=net0 \
    -global driver=cfi.pflash01,property=secure,value=on \
    -global ICH9-LPC.disable_s3=1 \
    -global ICH9-LPC.disable_s4=1 \
    -boot menu=on,strict=on \
    -device virtio-vga \
    -device intel-hda \
    $DRIVE_ARGS \
    -vnc :0
