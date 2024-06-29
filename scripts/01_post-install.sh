#!/bin/sh

PRIVATE_IP_NETWORK="192.168.50.0/24"
GUEST_SUBNETS="
172.16.0.0/16
172.17.0.0/16
"
ADDITIONAL_IPS="
172.17.0.0
172.17.0.1
"
SUDO=
if which sudo >/dev/null 2>&1; then
    SUDO=sudo
fi
$SUDO true
if [ -f $HOME/.env ]; then
    . $HOME/.env
    cat $HOME/.env
    rm $HOME/.env
else
    GATEWAY="$(ip route | grep default | awk '{ print $3 }')"
    INTERFACE="$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/ .*//")"
    PUBLIC_IP_ADDRESS_CIDR="$(ip addr show $INTERFACE | grep -E "^ *inet" | awk '{ print $2 }' | head -n1)"
    if [ "$INTERFACE" = "vmbr0" ]; then
        INTERFACE="$(ip addr | grep "vmbr0 state UP" | sed 's|^[0-9]*:\s*||g' | cut -d':' -f1)"
    else
        _INTERFACE="$(ip addr show $INTERFACE | grep -E "^ *altname" | awk '{ print $2 }' | head -n1)"
        if [ "$_INTERFACE" != "" ]; then
            INTERFACE="$_INTERFACE"
        fi
    fi
fi
PUBLIC_IP_ADDRESS="$(echo $PUBLIC_IP_ADDRESS_CIDR | cut -d/ -f1)"
_NUMBER=$(echo "$(hostname)" | sed 's/[^0-9]//g')
if [ "$_NUMBER" = "" ] || [ "$_NUMBER" -gt 245 ]; then
    echo "Error: Host number must be between 1 and 245." >&2
    exit 1
fi
PRIVATE_IP_ADDRESS="$(echo $PRIVATE_IP_NETWORK | cut -d. -f1-3).$(($_NUMBER + 9))"
if ping -c 1 -W 1 "$PRIVATE_IP_ADDRESS" >/dev/null 2>&1; then
    echo "Error: Proxmox is already installed on IP address $PRIVATE_IP_ADDRESS." >&2
    exit 1
fi
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
    iputils-ping \
    sudo \
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
cat <<EOF | $SUDO tee /etc/resolv.conf >/dev/null
nameserver 8.8.8.8
nameserver 4.4.4.4
nameserver 1.1.1.1
EOF
$SUDO sed -i 's|^#*\s*net.ipv4.ip_forward\s*=\s*.*|net.ipv4.ip_forward=1|' /etc/sysctl.conf
$SUDO sed -i 's|^#*\s*net.ipv6.conf.all.forwarding\s*=\s*.*|net.ipv6.conf.all.forwarding=1|' /etc/sysctl.conf
$SUDO sysctl -p
cat <<EOF | $SUDO tee /etc/network/interfaces >/dev/null
auto lo
iface lo inet loopback
iface lo inet6 loopback

auto $INTERFACE
iface $INTERFACE inet manual

auto vmbr0
iface vmbr0 inet static
    address      $PUBLIC_IP_ADDRESS_CIDR
    gateway      $GATEWAY
    bridge-ports $INTERFACE
    bridge-stp   off
    bridge-fd    0
$(echo "$ADDITIONAL_IPS" | sed '/^$/d; s|\(.*\)|    up ip route add \1/32 dev vmbr0|')

auto $INTERFACE.4000
iface $INTERFACE.4000 inet manual

auto vmbr1
iface vmbr1 inet static
    address      $PRIVATE_IP_ADDRESS/$(echo $PRIVATE_IP_NETWORK | cut -d/ -f2)
    bridge_ports $INTERFACE.4000
    bridge_stp   off
    bridge_fd    0
    mtu          1400
EOF
i=1
for GUEST_SUBNET in $GUEST_SUBNETS; do
GUEST_CIDR="$(echo $GUEST_SUBNET | cut -d/ -f1)/$(echo $GUEST_SUBNET | cut -d/ -f2)"
cat <<EOF | $SUDO tee -a /etc/network/interfaces >/dev/null

auto $INTERFACE.$((i + 4000))
iface $INTERFACE.$((i + 4000)) inet manual

auto vmbr$((i + 1))
iface vmbr$((i + 1)) inet static
    address      $GUEST_CIDR
    bridge-ports $INTERFACE.$((i + 4000))
    bridge-stp   off
    bridge-fd    0
    mtu          1400
    post-up      iptables -t nat -A POSTROUTING -s '$GUEST_CIDR' -o vmbr0 -j MASQUERADE
    post-down    iptables -t nat -D POSTROUTING -s '$GUEST_CIDR' -o vmbr0 -j MASQUERADE
    post-up      iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
    post-down    iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
EOF
i=$((i + 1))
done
if [ "$_ADDED_USER" = "1" ]; then
    $SUDO passwd admin
fi
