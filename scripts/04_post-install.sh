#!/bin/sh

. $HOME/.env
cat $HOME/.env
rm $HOME/.env
SUDO=
if which sudo >/dev/null 2>&1; then
    SUDO=sudo
fi
$SUDO true
export DEBIAN_FRONTEND=noninteractive
$SUDO rm -rf /etc/apt/sources.list.d/*
$SUDO apt-get update
$SUDO apt-get upgrade -y
$SUDO apt-get install -y \
    bind9-host \
    curl \
    iputils-ping \
    sudo \
    vim
if ! id -u admin >/dev/null 2>&1; then
    $SUDO adduser --disabled-password --gecos "" admin
fi
$SUDO usermod -aG sudo admin
$SUDO sed -i 's|^\%sudo.*|\%sudo	ALL=(ALL:ALL) NOPASSWD:ALL|' /etc/sudoers
$SUDO sed -i 's|^PermitRootLogin.*|PermitRootLogin no|' /etc/ssh/sshd_config
if [ ! -f /etc/network/interfaces.d/rescue_bridge ]; then
    $SUDO cp /etc/network/interfaces /etc/network/interfaces.d/rescue_bridge
    $SUDO sed -i 's|vmbr0|rescue_bridge|' /etc/network/interfaces.d/rescue_bridge
    $SUDO sed -i 's|source /etc/network/interfaces.d/\*||' /etc/network/interfaces.d/rescue_bridge
fi
cat <<EOF > /etc/network/interfaces
#LoopBacks
auto lo
iface lo inet loopback
iface lo inet6 loopback
 
#Physical Interfaces
iface $INTERFACE_ALTNAME inet manual
 
#Non-Proxmox Interfaces
source /etc/network/interfaces.d/*
 
#Proxmox Interfaces
#Public Interface
auto vmbr0
iface vmbr0 inet static
      address      $IP_ADDRESS_CIDR
      gateway      $GATEWAY
      bridge-ports $INTERFACE_ALTNAME
      bridge-stp   off
      bridge-fd    0
      up           sysctl -p
 
auto vmbr2
iface vmbr2 inet static
      address      192.168.192.5/18
      bridge-ports none
      bridge-stp   off
      bridge-fd    0
      post-up      iptables -t nat -A POSTROUTING -s '192.168.192.0/18' -o vmbr0 -j MASQUERADE
      post-down    iptables -t nat -D POSTROUTING -s '192.168.192.0/18' -o vmbr0 -j MASQUERADE
      post-up      iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
      post-down    iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
EOF
$SUDO sed -i 's|^#*\s*net.ipv4.ip_forward\s*=\s*.*|net.ipv4.ip_forward=1|' /etc/sysctl.conf
$SUDO sed -i 's|^#*\s*net.ipv6.conf.all.forwarding\s*=\s*.*|net.ipv6.conf.all.forwarding=1|' /etc/sysctl.conf
if ! cat /etc/modules | grep -q nf_conntrack; then
    echo nf_conntrack | $SUDO tee -a /etc/modules
fi
if ! cat /home/admin/.profile | grep -qE '^PATH="\$PATH:/usr/sbin"'; then
    echo 'PATH="$PATH:/usr/sbin"' | $SUDO tee -a /home/admin/.profile >/dev/null
fi
if [ ! -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak ]; then
    $SUDO cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak
    $SUDO sed -i 's|^\s*checked_command:\s*function(orig_cmd)\s*{.*|    checked_command: function(orig_cmd) { orig_cmd(); return;|g' \
        /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    $SUDO systemctl restart pveproxy.service
fi
cat <<EOF | $SUDO tee /etc/resolv.conf >/dev/null
nameserver 8.8.8.8
nameserver 4.4.4.4
nameserver 1.1.1.1
EOF
$SUDO passwd admin
$SUDO ifreload -a || true
$SUDO systemctl restart sshd
$SUDO systemctl poweroff
