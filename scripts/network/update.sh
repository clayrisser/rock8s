#!/bin/sh

PRIVATE_IP_NETWORK="${PRIVATE_IP_NETWORK:="192.168.1.0/24"}"
CEPH_NETWORK="${CEPH_NETWORK:="192.168.2.0/24"}"
STARTING_GUEST_SUBNET="${STARTING_GUEST_SUBNET:="172.20.0.0/16"}"
EXTRA_GUEST_SUBNETS_COUNT="1"
K8S_GUEST_SUBNETS_COUNT="${K8S_GUEST_SUBNETS_COUNT:="1"}"
MAX_SERVERS="${MAX_SERVERS:="64"}"
ADDITIONAL_IPS="${ADDITIONAL_IPS:=""}"
VSWITCH_MTU="${VSWITCH_MTU:="1400"}"
NAMESERVERS="${NAMESERVERS:-"
8.8.8.8
4.4.4.4
1.1.1.1
"}"

echo PRIVATE_IP_NETWORK=$PRIVATE_IP_NETWORK
echo CEPH_NETWORK=$CEPH_NETWORK
echo STARTING_GUEST_SUBNET=$STARTING_GUEST_SUBNET
echo EXTRA_GUEST_SUBNETS_COUNT=$EXTRA_GUEST_SUBNETS_COUNT
echo K8S_GUEST_SUBNETS_COUNT=$K8S_GUEST_SUBNETS_COUNT
echo MAX_SERVERS=$MAX_SERVERS
echo ADDITIONAL_IPS="\"$ADDITIONAL_IPS\""
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
    current_subnet="$(next_subnet "$(next_subnet "$current_subnet")")"
done
current_subnet="$(next_subnet "$STARTING_GUEST_SUBNET")"
for i in $(seq 0 $((K8S_GUEST_SUBNETS_COUNT - 1))); do
    _GUEST_SUBNETS="$_GUEST_SUBNETS\n$current_subnet"
    current_subnet="$(next_subnet "$(next_subnet "$current_subnet")")"
done
_GUEST_SUBNETS="$(echo "$_GUEST_SUBNETS" | sort -u)"

generate_dhcp_config() {
    cidr="$1"
    num_servers="$2"
    server_index="$3"
    if [ $((num_servers % 2)) -ne 0 ]; then
        echo "Error: Number of servers must be an even number." >&2
        exit 1
    fi
    subnet=$(echo "$cidr" | cut -d '/' -f 1)
    prefix=$(echo "$cidr" | cut -d '/' -f 2)
    subnet_mask=$(cidr2mask "$prefix")
    IFS=. read i1 i2 i3 i4 <<EOF
$subnet
EOF
    host_bits=$(( 32 - prefix ))
    num_hosts=$(( (1 << host_bits) - 2 ))
    hosts_per_server=$(( num_hosts / num_servers ))
    range_start_ip=$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 + (hosts_per_server * (server_index - 1)) + (server_index - 1) ))
    range_end_ip=$(( range_start_ip + hosts_per_server ))
    if [ "$server_index" -eq 1 ]; then
        range_start_ip=$(( range_start_ip + 2 ))
    fi
    if [ "$server_index" -eq "$num_servers" ]; then
        range_end_ip=$(( range_end_ip - 1 ))
    fi
    range_start=$(printf "%d.%d.%d.%d" \
                  $(( (range_start_ip >> 24) & 255 )) \
                  $(( (range_start_ip >> 16) & 255 )) \
                  $(( (range_start_ip >> 8) & 255 )) \
                  $(( range_start_ip & 255 )))
    range_end=$(printf "%d.%d.%d.%d" \
                $(( (range_end_ip >> 24) & 255 )) \
                $(( (range_end_ip >> 16) & 255 )) \
                $(( (range_end_ip >> 8) & 255 )) \
                $(( range_end_ip & 255 )))
    echo "subnet $subnet netmask $subnet_mask {"
    echo "    range $range_start $range_end;"
    echo "    option routers $(echo "$subnet" | awk -F. '{print $1"."$2"."$3".1"}');"
    echo "    option subnet-mask $subnet_mask;"
    echo "    option domain-name-servers $(echo "$NAMESERVERS" | \
        awk 'BEGIN{RS=""; ORS="\n"} {print}' | \
        tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g');"
    echo "}"
    echo
}

cidr2mask() {
    prefix="$1"
    shift=$(( 32 - prefix ))
    mask=$(( (1 << 32) - (1 << shift) ))
    printf "%d.%d.%d.%d\n" \
           $(( (mask >> 24) & 255 )) \
           $(( (mask >> 16) & 255 )) \
           $(( (mask >> 8) & 255 )) \
           $(( mask & 255 ))
}

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
    PUBLIC_IP_ADDRESS_CIDR="$(ip addr show "$(ip route | awk '/default via/ {print $5}')" | \
        grep -E "^ *inet" | awk '{ print $2 }' | head -n1)"
    NETWORK_DEVICES_BY_ROLE="$(sh "$(dirname "$0")/devices-by-role.sh")"
    echo GATEWAY=$GATEWAY
    echo PUBLIC_IP_ADDRESS_CIDR=$PUBLIC_IP_ADDRESS_CIDR
    echo NETWORK_DEVICES_BY_ROLE="\"$NETWORK_DEVICES_BY_ROLE\""
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
$(echo "$ADDITIONAL_IPS" | sed '/^$/d; s|\(.*\)|    up ip route add \1/32 dev vmbr0|')

$(if [ "$PRIVATE_DEVICE" = "" ]; then
    echo "auto $UPLINK_DEVICE.4000"
    echo "iface $UPLINK_DEVICE.4000 inet manual"
fi)

auto vmbr1
iface vmbr1 inet static
    address      $PRIVATE_IP_ADDRESS/$(echo $PRIVATE_IP_NETWORK | cut -d/ -f2)
$(if [ "$PRIVATE_DEVICE" = "" ]; then
    echo "    bridge-ports $UPLINK_DEVICE.4000"
    echo "    mtu          $VSWITCH_MTU"
else
    echo "    bridge-ports $PRIVATE_DEVICE"
fi)
    bridge-stp   off
    bridge-fd    0

auto vmbr2
iface vmbr2 inet static
    address      $CEPH_IP_ADDRESS/$(echo $CEPH_NETWORK | cut -d/ -f2)
$(if [ "$CEPH_DEVICE" = "" ]; then
    echo "    bridge-ports $UPLINK_DEVICE.4001"
    echo "    mtu          $VSWITCH_MTU"
else
    echo "    bridge-ports $CEPH_DEVICE"
fi)
    bridge-stp   off
    bridge-fd    0
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
    if [ "$DHCP_INTERFACES" = "" ]; then
        DHCP_INTERFACES="vmbr$(echo $_VLAN_ID | sed 's|^40||')"
    else
        DHCP_INTERFACES="$DHCP_INTERFACES vmbr$(echo $_VLAN_ID | sed 's|^40||')"
    fi
    cat <<EOF | $SUDO tee -a /etc/network/interfaces >/dev/null

auto $UPLINK_DEVICE.$_VLAN_ID
iface $UPLINK_DEVICE.$_VLAN_ID inet manual

auto vmbr$(echo $_VLAN_ID | sed 's|^40||')
iface vmbr$(echo $_VLAN_ID | sed 's|^40||') inet static
    address      $(echo $GUEST_SUBNET | sed 's|^\(.*\)\.\([0-9]\)*\/\([0-9]*\)$|\1.1/\3|g')
    bridge-ports $UPLINK_DEVICE.$_VLAN_ID
    bridge-stp   off
    bridge-fd    0
    mtu          $VSWITCH_MTU
    post-up      iptables -t nat -A POSTROUTING -s '$GUEST_SUBNET' -o vmbr0 -j MASQUERADE
    post-down    iptables -t nat -D POSTROUTING -s '$GUEST_SUBNET' -o vmbr0 -j MASQUERADE
    post-up      iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
    post-down    iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
EOF
    i=$((i + 1))
done
true | $SUDO tee /etc/dhcp/dhcpd.conf >/dev/null
for GUEST_SUBNET in $_GUEST_SUBNETS; do
    generate_dhcp_config "$GUEST_SUBNET" "$MAX_SERVERS" "$HOST_NUMBER" | \
        $SUDO tee -a /etc/dhcp/dhcpd.conf >/dev/null
done
$SUDO sed -i ':a;N;$!ba;s/\n\n\n*/\n\n/g' /etc/default/isc-dhcp-server
$SUDO sed -i ':a;N;$!ba;s/\n\n\n*/\n\n/g' /etc/dhcp/dhcpd.conf
$SUDO sed -i ':a;N;$!ba;s/\n\n\n*/\n\n/g' /etc/hosts
$SUDO sed -i ':a;N;$!ba;s/\n\n\n*/\n\n/g' /etc/network/interfaces
$SUDO sed -i ':a;N;$!ba;s/\n\n\n*/\n\n/g' /etc/resolv.conf
$SUDO sed -i '${/^$/d;}' /etc/default/isc-dhcp-server
$SUDO sed -i '${/^$/d;}' /etc/dhcp/dhcpd.conf
$SUDO sed -i '${/^$/d;}' /etc/hosts
$SUDO sed -i '${/^$/d;}' /etc/network/interfaces
$SUDO sed -i '${/^$/d;}' /etc/resolv.conf
$SUDO sed -i "s|^#*\s*INTERFACESv4=.*|INTERFACESv4=\"$DHCP_INTERFACES\"|" /etc/default/isc-dhcp-server
printf "\n\033[1;36m/etc/network/interfaces\033[0m\n"
$SUDO cat /etc/network/interfaces
printf "\n"
printf "\033[1;36m/etc/default/isc-dhcp-server\033[0m\n"
$SUDO cat /etc/default/isc-dhcp-server
printf "\n"
printf "\033[1;36m/etc/dhcp/dhcpd.conf\033[0m\n"
$SUDO cat /etc/dhcp/dhcpd.conf
printf "\n"
printf "\033[1;36m/etc/resolv.conf\033[0m\n"
$SUDO cat /etc/resolv.conf
printf "\n"
printf "\033[1;36m/etc/hosts\033[0m\n"
$SUDO cat /etc/hosts
printf "\n"
printf "\033[1;33mrestart the networking and dhcp services after reviewing the changes\033[0m\n"
printf "\n"
printf "    \033[0;32msudo systemctl restart networking\033[0m\n"
printf "    \033[0;32msudo systemctl restart isc-dhcp-server\033[0m\n"
printf "\n"
