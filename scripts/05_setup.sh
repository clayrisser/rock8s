#!/bin/sh

IMAGES="
https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso
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
wget -qO- https://download.ceph.com/keys/release.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/ceph.gpg >/dev/null
sudo apt-add-repository -y "deb https://download.ceph.com/debian-reef/ $(lsb_release -cs) main"
sudo systemctl mask rpcbind
sudo apt install -y isc-dhcp-server
if ! (cat /etc/dhcp/dhcpd.conf | grep -qE "^subnet "); then
    cat <<EOF | sudo tee -a /etc/dhcp/dhcpd.conf >/dev/null
subnet 192.168.192.0 netmask 255.255.192.0 {
    range 192.168.201.0 192.168.201.255;
    option routers 192.168.192.5;
    option subnet-mask 255.255.192.0;
    option domain-name-servers 8.8.8.8, 4.4.4.4, 1.1.1.1;
}
EOF
fi
sudo sed -i 's|^#*\s*INTERFACESv4=.*|INTERFACESv4="vmbr2"|' /etc/default/isc-dhcp-server
sudo systemctl restart isc-dhcp-server
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
for d in $(ls yams/images); do
    cp yams/images/$d/.env.example yams/images/$d/.env
    set -- $(sudo pveum user token add root@pam "$(tr -dc 'a-z' < /dev/urandom | head -c 8)" --privsep 0 -o json | \
        jq -r '([.["full-tokenid"],.value]) | @tsv')
    PROXMOX_TOKEN_ID="$1"
    PROXMOX_TOKEN_SECRET="$2"
    sed -i "s|^PROXMOX_HOST=.*|PROXMOX_HOST=localhost:8006|" yams/images/$d/.env
    sed -i "s|^PROXMOX_NODE=.*|PROXMOX_NODE=$(hostname)|" yams/images/$d/.env
    sed -i "s|^PROXMOX_TOKEN_ID=.*|PROXMOX_TOKEN_ID=$PROXMOX_TOKEN_ID|" yams/images/$d/.env
    sed -i "s|^PROXMOX_TOKEN_SECRET=.*|PROXMOX_TOKEN_SECRET=$PROXMOX_TOKEN_SECRET|" yams/images/$d/.env
done
