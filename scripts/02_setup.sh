#!/bin/sh

IMAGES="
https://cdimage.debian.org/mirror/cdimage/archive/12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso
https://download.fedoraproject.org/pub/fedora/linux/releases/40/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-40-1.14.iso
"
sudo true
export DEBIAN_FRONTEND=noninteractive
sudo apt install -y \
    cloud-init \
    git \
    git-lfs \
    jq \
    make \
    software-properties-common \
    systemd-timesyncd
git lfs install
wget -qO- https://download.ceph.com/keys/release.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/ceph.gpg >/dev/null
sudo apt-add-repository -y "deb https://download.ceph.com/debian-reef/ $(lsb_release -cs) main"
sudo systemctl mask rpcbind
for IMAGE in $IMAGES; do
    (cd /var/lib/vz/template/iso && sudo curl -LO "$IMAGE")
done
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install -y \
    packer
if [ ! -d yams ]; then
    git clone https://gitlab.com/bitspur/rock8s/yams.git
fi
set -- $(sudo pveum user token add root@pam "$(tr -dc 'a-z' < /dev/urandom | head -c 8)" --privsep 0 -o json | \
    jq -r '([.["full-tokenid"],.value]) | @tsv')
PROXMOX_TOKEN_ID="$1"
PROXMOX_TOKEN_SECRET="$2"
export STORAGE_POOL="$( (sudo pvesm status | grep -q local-zfs) && echo local-zfs || ( (sudo pvesm status | grep -q local-lvm) && echo local-lvm || echo local))"
for d in $(ls yams/images); do
    cp yams/images/$d/.env.example yams/images/$d/.env
    sed -i "s|^PROXMOX_HOST=.*|PROXMOX_HOST=localhost:8006|" yams/images/$d/.env
    sed -i "s|^PROXMOX_NODE=.*|PROXMOX_NODE=$(hostname)|" yams/images/$d/.env
    sed -i "s|^PROXMOX_TOKEN_ID=.*|PROXMOX_TOKEN_ID=$PROXMOX_TOKEN_ID|" yams/images/$d/.env
    sed -i "s|^PROXMOX_TOKEN_SECRET=.*|PROXMOX_TOKEN_SECRET=$PROXMOX_TOKEN_SECRET|" yams/images/$d/.env
    (cd yams/images/$d && make build)
done
sudo pveum user token remove "$(echo $PROXMOX_TOKEN_ID | cut -d'!' -f1)" "$(echo $PROXMOX_TOKEN_ID | cut -d'!' -f2)"
