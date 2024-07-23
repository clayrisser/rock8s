#!/bin/sh

ADDITIONAL_IPS="${ADDITIONAL_IPS:=""}"
CEPH_NETWORK="${CEPH_NETWORK:="192.168.2.0/24"}"
EXTRA_GUEST_SUBNETS_COUNT="${EXTRA_GUEST_SUBNETS_COUNT:="2"}"
MAX_SERVERS="${MAX_SERVERS:="64"}"
PRIVATE_IP_NETWORK="${PRIVATE_IP_NETWORK:="192.168.1.0/24"}"
STARTING_GUEST_SUBNET="${STARTING_GUEST_SUBNET:="172.20.0.0/16"}"
VSWITCH_MTU="${VSWITCH_MTU:="1400"}"
NAMESERVERS="${NAMESERVERS:-"
8.8.8.8
8.8.4.4
1.1.1.1
"}"

echo ADDITIONAL_IPS="\"$ADDITIONAL_IPS\""
echo CEPH_NETWORK=$CEPH_NETWORK
echo EXTRA_GUEST_SUBNETS_COUNT=$EXTRA_GUEST_SUBNETS_COUNT
echo MAX_SERVERS=$MAX_SERVERS
echo PRIVATE_IP_NETWORK=$PRIVATE_IP_NETWORK
echo STARTING_GUEST_SUBNET=$STARTING_GUEST_SUBNET
echo VSWITCH_MTU=$VSWITCH_MTU
echo NAMESERVERS="\"$NAMESERVERS\""

next_subnet() {
    cidr=$1
    broadcast_ip=$(sipcalc "$cidr" | grep "Broadcast address" | awk -F'- ' '{print $2}')
    IFS='.' read -r octet1 octet2 octet3 octet4 <<EOF
$broadcast_ip
EOF
    octet4=$((octet4+1))
    if [ $octet4 -eq 256 ]; then
        octet4=0
        octet3=$((octet3+1))
        if [ $octet3 -eq 256 ]; then
            octet3=0
            octet2=$((octet2+1))
            if [ $octet2 -eq 256 ]; then
                octet2=0
                octet1=$((octet1+1))
            fi
        fi
    fi
    next_subnet_start="$octet1.$octet2.$octet3.$octet4"
    next_subnet="$next_subnet_start/${cidr#*/}"
    echo $next_subnet
}

_GUEST_SUBNETS=""
current_subnet="$STARTING_GUEST_SUBNET"
for i in $(seq 0 $((EXTRA_GUEST_SUBNETS_COUNT - 1))); do
    _GUEST_SUBNETS="$_GUEST_SUBNETS\n$current_subnet"
    current_subnet="$(next_subnet "$current_subnet")"
done
_GUEST_SUBNETS="$(echo "$_GUEST_SUBNETS" | sort -u)"

SUDO=
if which sudo >/dev/null 2>&1; then
    SUDO=sudo
fi
$SUDO true
for _IFACE in $(ls /sys/class/net); do
    $SUDO ip link set "$_IFACE" up
done
if [ -f $HOME/.env ]; then
    . $HOME/.env
    cat $HOME/.env
    rm $HOME/.env
else
    GATEWAY="$(ip route | grep default | grep "dev vmbr0" | awk '{ print $3 }')"
    IPV6_GATEWAY="$(ip -6 route | grep default | grep "dev vmbr0" | awk '{ print $3 }')"
    PUBLIC_IP_ADDRESS_CIDR="$(ip addr show "$(ip route | awk '/default via/ {print $5}')" | \
        grep -E "^ *inet" | awk '{ print $2 }' | head -n1)"
    PUBLIC_IPV6_ADDRESS_CIDR="$(ip -6 addr show vmbr0 | \
        grep -E "^ *inet6" | awk '{ print $2 }' | grep -v '^fe80' | head -n1)"
    NETWORK_DEVICES_BY_ROLE="$(sh "$(dirname "$0")/devices-by-role.sh")"
    echo GATEWAY=$GATEWAY
    echo IPV6_GATEWAY=$IPV6_GATEWAY
    echo NETWORK_DEVICES_BY_ROLE="\"$NETWORK_DEVICES_BY_ROLE\""
    echo PUBLIC_IPV6_ADDRESS_CIDR=$PUBLIC_IPV6_ADDRESS_CIDR
    echo PUBLIC_IP_ADDRESS_CIDR=$PUBLIC_IP_ADDRESS_CIDR
fi
UPLINK_DEVICE="$(echo "$NETWORK_DEVICES_BY_ROLE" | grep -E "^uplink:" | cut -d= -f1 | cut -d: -f2)"
PRIVATE_DEVICE="$(echo "$NETWORK_DEVICES_BY_ROLE" | grep -E "^private:" | cut -d= -f1 | cut -d: -f2)"
CEPH_DEVICE="$(echo "$NETWORK_DEVICES_BY_ROLE" | grep -E "^ceph:" | cut -d= -f1 | cut -d: -f2)"
PUBLIC_IP_ADDRESS="$(echo $PUBLIC_IP_ADDRESS_CIDR | cut -d/ -f1)"
HOST_NUMBER=$(echo "$(hostname)" | sed 's/[^0-9]//g')
echo HOST_NUMBER=$HOST_NUMBER
if [ "$HOST_NUMBER" = "" ] || [ "$HOST_NUMBER" -gt 245 ]; then
    echo "Error: host number must be between 1 and 245." >&2
    exit 1
fi
PRIVATE_IP_ADDRESS="$(echo $PRIVATE_IP_NETWORK | cut -d. -f1-3).$(($HOST_NUMBER + 10))"
echo PRIVATE_IP_ADDRESS=$PRIVATE_IP_ADDRESS
CEPH_IP_ADDRESS="$(echo $CEPH_NETWORK | cut -d. -f1-3).$(($HOST_NUMBER + 10))"
echo CEPH_IP_ADDRESS=$CEPH_IP_ADDRESS
$SUDO sed -i "s|.*[0-9]\s*\($(hostname).*\)|$PRIVATE_IP_ADDRESS \1|g" /etc/hosts
echo "$NAMESERVERS" | awk 'BEGIN{RS=""; ORS="\n\n"} {print}' | \
    awk '{for (i=1; i<=NF; i++) print "nameserver", $i}' | $SUDO tee /etc/resolv.conf >/dev/null
$SUDO sed -i 's|^#*\s*net.ipv4.ip_forward\s*=\s*.*|net.ipv4.ip_forward=1|' /etc/sysctl.conf
$SUDO sed -i 's|^#*\s*net.ipv6.conf.all.forwarding\s*=\s*.*|net.ipv6.conf.all.forwarding=1|' /etc/sysctl.conf
$SUDO sysctl -p >/dev/null
cat <<EOF | $SUDO tee /etc/network/interfaces >/dev/null
auto lo
iface lo inet loopback
iface lo inet6 loopback

auto $UPLINK_DEVICE
iface $UPLINK_DEVICE inet manual

$(if [ "$PRIVATE_DEVICE" != "" ]; then
    echo "auto $PRIVATE_DEVICE"
    echo "iface $PRIVATE_DEVICE inet manual"
fi)

$(if [ "$CEPH_DEVICE" != "" ]; then
    echo "auto $CEPH_DEVICE"
    echo "iface $CEPH_DEVICE inet manual"
fi)

auto vmbr0
iface vmbr0 inet static
    address      $PUBLIC_IP_ADDRESS_CIDR
    gateway      $GATEWAY
    bridge-ports $UPLINK_DEVICE
    bridge-stp   off
    bridge-fd    0
$(echo "$ADDITIONAL_IPS" | sed '/^$/d; s|\(.*\)|    up ip route add \1/32 dev vmbr0|'; \
    ([ "$PUBLIC_IPV6_ADDRESS_CIDR" != "" ] && echo "iface vmbr0 inet6 static
    address      $PUBLIC_IPV6_ADDRESS_CIDR" && \
    [ "$IPV6_GATEWAY" != "" ] && echo "    gateway      $IPV6_GATEWAY"))

$(if [ "$PRIVATE_DEVICE" = "" ]; then
    echo "auto $UPLINK_DEVICE.4000"
    echo "iface $UPLINK_DEVICE.4000 inet manual"
fi)

auto vmbr1
iface vmbr1 inet static
    address         $PRIVATE_IP_ADDRESS/$(echo $PRIVATE_IP_NETWORK | cut -d/ -f2)
$(if [ "$PRIVATE_DEVICE" = "" ]; then
    echo "    bridge-ports    $UPLINK_DEVICE.4000"
    echo "    mtu             $VSWITCH_MTU"
    echo "    vlan-raw-device $UPLINK_DEVICE"
else
    echo "    bridge-ports    $PRIVATE_DEVICE"
fi)
    bridge-stp      off
    bridge-fd       0

auto vmbr2
iface vmbr2 inet static
    address         $CEPH_IP_ADDRESS/$(echo $CEPH_NETWORK | cut -d/ -f2)
$(if [ "$CEPH_DEVICE" = "" ]; then
    echo "    bridge-ports    $UPLINK_DEVICE.4001"
    echo "    mtu             $VSWITCH_MTU"
    echo "    vlan-raw-device $UPLINK_DEVICE"
else
    echo "    bridge-ports    $CEPH_DEVICE"
fi)
    bridge-stp      off
    bridge-fd       0
EOF
_VLAN_ID_START=20
_VLAN_IDS=""
_unique_vlan_id() {
    _VLAN_ID="40$_VLAN_ID_START"
    while echo "$_VLAN_IDS" | grep -q "$_VLAN_ID"; do
        _VLAN_ID="$((_VLAN_ID + 1))"
        if [ "$_VLAN_ID" -gt 4094 ]; then
            echo "Error: vlan ids exceeded 4094" >&2
            exit 1
        fi
    done
    echo "$_VLAN_ID"
}
i=$_VLAN_ID_START
for GUEST_SUBNET in $_GUEST_SUBNETS; do
    if echo "$GUEST_SUBNET" | grep -qE '^172\.[0-9][0-9]\.0\.0\/16$'; then
        _VLAN_ID="$(echo "$GUEST_SUBNET" | sed 's|172\.\([0-9][0-9]\)\.0\.0\/16|40\1|g')"
    else
        _VLAN_ID="40$i"
    fi
    if echo "$_VLAN_IDS" | grep -q "$_VLAN_ID"; then
        _VLAN_ID="$(_unique_vlan_id)"
    fi
    _VLAN_IDS="$_VLAN_IDS $_VLAN_ID"
    _INTERFACE="vmbr$(echo $_VLAN_ID | sed 's|^40||')"
    IPV6_SUBNET="$(cat "$HOME/shared/subnets.yaml" | \
        perl -MYAML::XS=Load -MJSON=encode_json -E 'say encode_json(Load(join "", <STDIN>))' | \
        jq -r ".$_INTERFACE.ipv6.subnet // \"\"")"
    IPV6_GATEWAY="$(cat "$HOME/shared/subnets.yaml" | \
        perl -MYAML::XS=Load -MJSON=encode_json -E 'say encode_json(Load(join "", <STDIN>))' | \
        jq -r ".$_INTERFACE.ipv6.gateway // \"\"")"
    IPV4_SUBNET="$(cat "$HOME/shared/subnets.yaml" | \
        perl -MYAML::XS=Load -MJSON=encode_json -E 'say encode_json(Load(join "", <STDIN>))' | \
        jq -r ".$_INTERFACE.ipv4.subnet // \"\"")"
    IPV4_GATEWAY="$(cat "$HOME/shared/subnets.yaml" | \
        perl -MYAML::XS=Load -MJSON=encode_json -E 'say encode_json(Load(join "", <STDIN>))' | \
        jq -r ".$_INTERFACE.ipv4.gateway // \"\"")"
    cat <<EOF | $SUDO tee -a /etc/network/interfaces >/dev/null

auto $UPLINK_DEVICE.$_VLAN_ID
iface $UPLINK_DEVICE.$_VLAN_ID inet manual

auto $_INTERFACE
iface $_INTERFACE inet static$(if [ "$IPV4_SUBNET" = "" ] && [ "$IPV4_GATEWAY" = "" ]; then \
    echo "
    address         $(echo $GUEST_SUBNET | sed "s|^\(.*\)\.\([0-9]\)*\/\([0-9]*\)$|\1.$HOST_NUMBER/\3|g")"; fi)
    bridge-ports    $UPLINK_DEVICE.$_VLAN_ID
    vlan-raw-device $UPLINK_DEVICE
    bridge-stp      off
    bridge-fd       0
    mtu             $VSWITCH_MTU
EOF
    if [ "$IPV4_SUBNET" = "" ] && [ "$IPV4_GATEWAY" = "" ]; then
        cat <<EOF | $SUDO tee -a /etc/network/interfaces >/dev/null
    post-up         iptables -t nat -A POSTROUTING -s '$GUEST_SUBNET' -o vmbr0 -j MASQUERADE
    post-down       iptables -t nat -D POSTROUTING -s '$GUEST_SUBNET' -o vmbr0 -j MASQUERADE
    post-up         iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
    post-down       iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
EOF
    fi
    if [ "$IPV6_SUBNET" != "" ] && [ "$IPV6_GATEWAY" != "" ]; then
        cat <<EOF | $SUDO tee -a /etc/network/interfaces >/dev/null
iface $_INTERFACE inet6 static
EOF
    fi
    i=$((i + 1))
done
for GUEST_SUBNET in $_GUEST_SUBNETS; do
    if echo "$GUEST_SUBNET" | grep -qE '^172\.[0-9][0-9]\.0\.0\/16$'; then
        _VLAN_ID="$(echo "$GUEST_SUBNET" | sed 's|172\.\([0-9][0-9]\)\.0\.0\/16|40\1|g')"
    else
        _VLAN_ID="40$i"
    fi
    _INTERFACE="vmbr$(echo $_VLAN_ID | sed 's|^40||')"
    IPV6_SUBNET="$(cat "$HOME/shared/subnets.yaml" | \
        perl -MYAML::XS=Load -MJSON=encode_json -E 'say encode_json(Load(join "", <STDIN>))' | \
        jq -r ".$_INTERFACE.ipv6.subnet // \"\"")"
done
$SUDO sed -i ':a;N;$!ba;s/\n\n\n*/\n\n/g' /etc/hosts
$SUDO sed -i ':a;N;$!ba;s/\n\n\n*/\n\n/g' /etc/network/interfaces
$SUDO sed -i ':a;N;$!ba;s/\n\n\n*/\n\n/g' /etc/resolv.conf
$SUDO sed -i '${/^$/d;}' /etc/hosts
$SUDO sed -i '${/^$/d;}' /etc/network/interfaces
$SUDO sed -i '${/^$/d;}' /etc/resolv.conf
printf "\n\033[1;36m/etc/network/interfaces\033[0m\n"
$SUDO cat /etc/network/interfaces
printf "\n"
printf "\033[1;36m/etc/resolv.conf\033[0m\n"
$SUDO cat /etc/resolv.conf
printf "\n"
printf "\033[1;36m/etc/hosts\033[0m\n"
$SUDO cat /etc/hosts
printf "\n"
printf "\033[1;33mrestart the networking service after reviewing the changes\033[0m\n"
printf "\n"
printf "    \033[0;32msudo systemctl restart networking\033[0m\n"
printf "\n"
