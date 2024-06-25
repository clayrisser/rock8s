#!/bin/sh

IMAGES="
https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
"
sudo true
export DEBIAN_FRONTEND=noninteractive
sudo apt install -y \
    cloud-init \
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
