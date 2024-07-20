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
cat <<EOF | $SUDO tee /etc/apt/sources.list.d/pve-enterprise.list >/dev/null
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
EOF
cat <<EOF | $SUDO tee /etc/apt/sources.list.d/pve-install-repo.list 2>/dev/null
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
cat <<EOF | $SUDO tee /etc/apt/sources.list.d/ceph.list 2>/dev/null
# deb https://enterprise.proxmox.com/debian/ceph-quincy bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
# deb https://enterprise.proxmox.com/debian/ceph-reef bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription
EOF
cat <<EOF | $SUDO tee /etc/apt/sources.list.d/pvetest-for-beta.list >/dev/null
deb http://download.proxmox.com/debian/pve bookworm pvetest
EOF
$SUDO apt-get update
$SUDO apt-get upgrade -y
$SUDO apt-get dist-upgrade -y
$SUDO apt-get install -y \
    bind9-host \
    curl \
    git \
    git-lfs \
    iputils-ping \
    isc-dhcp-server \
    jq \
    make \
    radvd \
    sipcalc \
    software-properties-common \
    speedtest-cli \
    sudo \
    systemd-timesyncd \
    vim
if ! id -u admin >/dev/null 2>&1; then
    $SUDO adduser --disabled-password --gecos "" admin
    _ADDED_USER=1
fi
$SUDO usermod -aG sudo admin
$SUDO sed -i 's|^\%sudo.*|\%sudo	ALL=(ALL:ALL) NOPASSWD:ALL|' /etc/sudoers
$SUDO sed -i 's|^PermitRootLogin.*|PermitRootLogin no|' /etc/ssh/sshd_config
if ! cat /home/admin/.profile | grep -qE '^PATH="\$PATH:/usr/sbin"'; then
    echo 'PATH="$PATH:/usr/sbin"' | $SUDO tee -a /home/admin/.profile >/dev/null
fi
if [ ! -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak ]; then
    $SUDO cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak
    $SUDO sed -i 's|^\s*checked_command:\s*function(orig_cmd)\s*{.*|    checked_command: function(orig_cmd) { orig_cmd(); return;|g' \
        /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    $SUDO systemctl restart pveproxy.service
fi
if ! cat /etc/modules | grep -q nf_conntrack; then
    echo nf_conntrack | $SUDO tee -a /etc/modules
fi
$SUDO su -c "git lfs install" - admin
if [ ! -d /home/admin/yaps ]; then
    $SUDO su -c "git clone https://gitlab.com/bitspur/rock8s/yaps.git /home/admin/yaps" - admin
fi
$SUDO sh /home/admin/yaps/scripts/network/update.sh
if [ "$_ADDED_USER" = "1" ]; then
    $SUDO passwd admin
fi
echo "Please reboot the server"
