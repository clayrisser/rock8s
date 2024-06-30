#!/bin/sh

SUDO=
if which sudo >/dev/null 2>&1; then
    SUDO=sudo
fi
$SUDO true
export DEBIAN_FRONTEND=noninteractive
$SUDO curl -Lo /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg \
    http://download.proxmox.com/debian/proxmox-release-bookworm.gpg
$SUDO rm -rf /etc/apt/sources.list.d/*
cat <<EOF | $SUDO tee /etc/apt/sources.list >/dev/null
deb http://deb.debian.org/debian bookworm main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF
cat <<EOF | $SUDO tee /etc/apt/sources.list.d/pve-install-repo.list 2>/dev/null
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
cat <<EOF | $SUDO tee /etc/apt/sources.list.d/pvetest-for-beta.list >/dev/null
deb http://download.proxmox.com/debian/pve bookworm pvetest
EOF
$SUDO apt-get update
$SUDO apt-get upgrade -y
$SUDO apt-get dist-upgrade -y
$SUDO apt-get install -y \
    proxmox-ve
cat <<EOF | $SUDO tee /etc/apt/sources.list.d/pve-enterprise.list >/dev/null
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
EOF
cat <<EOF | $SUDO tee /etc/apt/sources.list.d/ceph.list 2>/dev/null
# deb https://enterprise.proxmox.com/debian/ceph-quincy bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
# deb https://enterprise.proxmox.com/debian/ceph-reef bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription
EOF
$SUDO apt-get update
$SUDO apt-get upgrade -y
$SUDO apt-get dist-upgrade -y
