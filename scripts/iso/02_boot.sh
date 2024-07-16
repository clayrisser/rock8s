#!/bin/sh

DRIVE_PREFIX="sd"
DRIVES="$(lsblk -dn -o NAME | grep -E "^$DRIVE_PREFIX" | sort | head -n2)"
DRIVE_ARGS=""
for DRIVE in $DRIVES; do
    DRIVE_ARGS="$DRIVE_ARGS -drive file=/dev/$DRIVE,format=raw,media=disk,if=virtio"
done
qemu-system-x86_64 -enable-kvm -bios /usr/share/ovmf/OVMF.fd -cpu host \
    -k en-us -device virtio-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 -smp 4 -m 4096 \
    $DRIVE_ARGS \
    -vnc :0
