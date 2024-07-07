#!/bin/sh

IMAGES="
https://cdimage.debian.org/mirror/cdimage/archive/12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso
https://download.fedoraproject.org/pub/fedora/linux/releases/40/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-40-1.14.iso
"
sudo true
export DEBIAN_FRONTEND=noninteractive
wget -qO- https://download.ceph.com/keys/release.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/ceph.gpg >/dev/null
sudo apt-add-repository -y "deb https://download.ceph.com/debian-reef/ $(lsb_release -cs) main"
sudo systemctl mask rpcbind
for IMAGE in $IMAGES; do
    FILENAME="$(basename "$IMAGE")"
    if [ ! -f "/var/lib/vz/template/iso/$FILENAME" ]; then
        (cd /var/lib/vz/template/iso && sudo curl -LO "$IMAGE")
    fi
done
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install -y \
    packer
set -- $(sudo pveum user token add root@pam "$(tr -dc 'a-z' < /dev/urandom | head -c 8)" --privsep 0 -o json | \
    jq -r '([.["full-tokenid"],.value]) | @tsv')
export PROXMOX_TOKEN_ID="$1"
export PROXMOX_TOKEN_SECRET="$2"
export STORAGE_POOL="$( (sudo pvesm status | grep -q local-zfs) && echo local-zfs || ( (sudo pvesm status | grep -q local-lvm) && echo local-lvm || echo local))"
export PROXMOX_NODE="$(hostname)"
export PROXMOX_HOST="localhost:8006"
make -sC $HOME/yaps images/build
sudo pveum user token remove "$(echo $PROXMOX_TOKEN_ID | cut -d'!' -f1)" "$(echo $PROXMOX_TOKEN_ID | cut -d'!' -f2)"
