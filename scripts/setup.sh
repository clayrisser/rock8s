#!/bin/sh

PFSENSE_VERSION=2.7.2
DEBIAN_VERSION=12.5.0
FEDORA_VERSION=40
YAPS_REPO="https://gitlab.com/bitspur/rock8s/yaps.git"
IMAGES="
https://cdimage.debian.org/mirror/cdimage/archive/$DEBIAN_VERSION/amd64/iso-cd/debian-$DEBIAN_VERSION-amd64-netinst.iso
https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_VERSION/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-$FEDORA_VERSION-1.14.iso
"
PFSENSE_IMAGE="https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-$PFSENSE_VERSION-RELEASE-amd64.iso.gz"

if [ ! "$USER" = "admin" ]; then
    echo "this script must be run as admin user" 1>&2
    exit 1
fi
if ! sudo pvesh get /cluster/status --output-format json | jq -e '.[0].quorate' >/dev/null; then
    echo "this script must be run on a proxmox cluster" 1>&2
    exit 1
fi
if ! [ -d "/mnt/pve/cephfs" ]; then
    echo "cephfs filesystem is required" 1>&2
    exit 1
fi
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
PFSENSE_FILENAME="pfSense-CE-$PFSENSE_VERSION-RELEASE-amd64.iso"
if [ ! -f "$ISO_DIR/$PFSENSE_FILENAME" ]; then
    sudo curl -Lo "$ISO_DIR/$PFSENSE_FILENAME.gz" "$PFSENSE_IMAGE"
    sudo gunzip -c "$ISO_DIR/$PFSENSE_FILENAME.gz" | \
    sudo tee "$ISO_DIR/$PFSENSE_FILENAME" > /dev/null
    sudo rm "$ISO_DIR/$PFSENSE_FILENAME.gz"
fi
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
sudo rm -rf /mnt/pve/cephfs/shared/tmp 2>/dev/null || true
sudo mkdir -p /mnt/pve/cephfs/shared/tmp
sudo chown -R $USER:$USER /mnt/pve/cephfs/shared
sudo cp "$HOME/.ssh/id_rsa" /mnt/pve/cephfs/shared/tmp
sudo cp "$HOME/.ssh/id_rsa.pub" /mnt/pve/cephfs/shared/tmp
if [ ! -f "$HOME/.ssh/authorized_keys" ]; then
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
fi
if ! grep -qxF "$(cat "$HOME/.ssh/id_rsa.pub")" "$HOME/.ssh/authorized_keys"; then
    cat "$HOME/.ssh/id_rsa.pub" >> "$HOME/.ssh/authorized_keys"
fi
if [ ! -d $HOME/shared ]; then
    ln -s /mnt/pve/cephfs/shared $HOME/shared
fi
if [ ! -L "$HOME/yaps" ]; then
    sudo rm -rf "$HOME/yaps"
    git clone "$YAPS_REPO" /mnt/pve/cephfs/shared/yaps
    ln -s /mnt/pve/cephfs/shared/yaps "$HOME/yaps"
fi
(cd "$HOME/yaps" && git pull origin main)
_NODES=$(sudo pvesh get /nodes --output-format json | jq -r '.[].node' | sort)
for _NODE in $_NODES; do
    _NODE_ID=$(sudo corosync-cmapctl | grep -oP "(?<=nodelist.node.)\d+(?=.name \(str\) = $_NODE)")
    _NODE_IP=$(sudo corosync-cmapctl | grep "nodelist.node.$_NODE_ID.ring0_addr" | awk -F' = ' '{print $2}')
    if [ "$_NODE_IP" != "" ]; then
        if ! grep -q "$_NODE_IP" /etc/hosts; then
            ssh $USER@$_NODE_IP "
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
                sudo mkdir -p /home/$USER/.ssh
                sudo chown -R $USER:$USER /home/$USER/.ssh
                sudo cp /mnt/pve/cephfs/shared/tmp/id_rsa /home/$USER/.ssh/id_rsa
                sudo cp /mnt/pve/cephfs/shared/tmp/id_rsa.pub /home/$USER/.ssh/id_rsa.pub
                sudo chown -R $USER:$USER /home/$USER/.ssh
                sudo chmod 600 /home/$USER/.ssh/id_rsa
                sudo chmod 644 /home/$USER/.ssh/id_rsa.pub
                if [ ! -f /home/$USER/.ssh/authorized_keys ]; then
                    touch /home/$USER/.ssh/authorized_keys
                    chmod 600 /home/$USER/.ssh/authorized_keys
                fi
                if ! grep -qxF \"\$(cat /home/$USER/.ssh/id_rsa.pub)\" /home/$USER/.ssh/authorized_keys; then
                    sudo cat /home/$USER/.ssh/id_rsa.pub >> /home/$USER/.ssh/authorized_keys
                fi
                if [ ! -d /home/$USER/shared ]; then
                    ln -s /mnt/pve/cephfs/shared /home/$USER/shared
                fi
                if [ ! -L "/home/$USER/yaps" ]; then
                    sudo rm -rf "/home/$USER/yaps"
                    ln -s /mnt/pve/cephfs/shared/yaps /home/$USER/yaps
                fi
            "
        fi
    fi
done
sudo rm -rf /mnt/pve/cephfs/shared/tmp
cd "$HOME"
