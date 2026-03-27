#!/bin/sh

set -e

export TF_VAR_libvirt_uri="$(get_config '.providers.libvirt.uri // ""' "qemu:///system")"

_ARCH="$(uname -m)"
case "$_ARCH" in
    aarch64|arm64)
        export TF_VAR_firmware="${TF_VAR_firmware:-/usr/share/AAVMF/AAVMF_CODE.fd}"
        export TF_VAR_arch="aarch64"
        export TF_VAR_machine="virt"
        _DEFAULT_IMAGE="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-arm64.qcow2"
        ;;
    x86_64|amd64)
        export TF_VAR_arch="x86_64"
        export TF_VAR_machine="pc"
        _DEFAULT_IMAGE="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
        ;;
    *)
        fail "unsupported architecture: $_ARCH"
        ;;
esac

if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    export TF_VAR_cpu_mode="host-passthrough"
    log "KVM acceleration available"
else
    export TF_VAR_cpu_mode=""
    warn "KVM not available, using QEMU TCG (software emulation, slower)"
fi

if [ -z "$TF_VAR_image" ] || [ "$TF_VAR_image" = "null" ]; then
    export TF_VAR_image="$(get_config '.providers.libvirt.image // ""' "$_DEFAULT_IMAGE")"
fi
