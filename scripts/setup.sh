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
ISO_DIR="$([ -d "/mnt/pve/cephfs/template/iso" ] && echo "/mnt/pve/cephfs/template/iso" || echo "/var/lib/vz/template/iso")"
for IMAGE in $IMAGES; do
    FILENAME="$(basename "$IMAGE")"
    if [ ! -f "$ISO_DIR/$FILENAME" ]; then
        (cd "$ISO_DIR" && sudo curl -LO "$IMAGE")
    fi
done
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install -y \
    packer \
    terraform
_DOMAIN=$(cat /etc/hosts | grep "$HOSTNAME" | grep -oE "$HOSTNAME\.[^ ]+" | sed "s|^$HOSTNAME\.||g")
mkdir -p "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -b 4096 -C "$(whoami)@$_DOMAIN" -N "" -f "$HOME/.ssh/id_rsa"
fi
sudo rm -rf /etc/pve/tmp 2>/dev/null || true
sudo mkdir -p /etc/pve/tmp
sudo cp "$HOME/.ssh/id_rsa" /etc/pve/tmp
sudo cp "$HOME/.ssh/id_rsa.pub" /etc/pve/tmp
if [ ! -f "$HOME/.ssh/authorized_keys" ]; then
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
fi
if ! grep -qxF "$(cat "$HOME/.ssh/id_rsa.pub")" "$HOME/.ssh/authorized_keys"; then
    cat "$HOME/.ssh/id_rsa.pub" >> "$HOME/.ssh/authorized_keys"
fi
_NODES=$(sudo pvesh get /nodes --output-format json | jq -r '.[].node' | sort)
for _NODE in $_NODES; do
    _NODE_ID=$(sudo corosync-cmapctl | grep -oP "(?<=nodelist.node.)\d+(?=.name \(str\) = $_NODE)")
    _NODE_IP=$(sudo corosync-cmapctl | grep "nodelist.node.$_NODE_ID.ring0_addr" | awk -F' = ' '{print $2}')
    if [ "$_NODE_IP" != "" ]; then
        if ! grep -q "$_NODE_IP" /etc/hosts; then
            ssh admin@$_NODE_IP "
                wget -qO- https://download.ceph.com/keys/release.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/ceph.gpg >/dev/null
                sudo apt-add-repository -y \"deb https://download.ceph.com/debian-reef/ \$(lsb_release -cs) main\"
                sudo systemctl mask rpcbind
                export DEBIAN_FRONTEND=noninteractive
                curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
                sudo apt-add-repository -y \"deb [arch=amd64] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\"
                sudo apt-get update
                sudo apt-get install -y \
                    packer \
                    terraform
                sudo mkdir -p /home/admin/.ssh
                sudo cp /etc/pve/tmp/id_rsa /home/admin/.ssh/id_rsa
                sudo cp /etc/pve/tmp/id_rsa.pub /home/admin/.ssh/id_rsa.pub
                sudo chown admin:admin /home/admin/.ssh/id_rsa
                sudo chown admin:admin /home/admin/.ssh/id_rsa.pub
                sudo chmod 600 /home/admin/.ssh/id_rsa
                sudo chmod 644 /home/admin/.ssh/id_rsa.pub
                if [ ! -f /home/admin/.ssh/authorized_keys ]; then
                    sudo touch /home/admin/.ssh/authorized_keys
                    sudo chmod 600 /home/admin/.ssh/authorized_keys
                fi
                if ! grep -qxF \"\$(cat /home/admin/.ssh/id_rsa.pub)\" /home/admin/.ssh/authorized_keys; then
                    sudo cat /home/admin/.ssh/id_rsa.pub >> /home/admin/.ssh/authorized_keys
                fi
            "
        fi
    fi
done
sudo rm -rf /etc/pve/tmp
make -sC $HOME/yaps images/build
