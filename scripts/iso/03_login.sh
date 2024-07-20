#!/bin/sh

GATEWAY="$(ip route | grep default | awk '{ print $3 }')"
IPV6_GATEWAY="$(ip -6 route | grep default | awk '{ print $3 }')"
PUBLIC_IP_ADDRESS_CIDR="$(ip addr show "$(ip route | awk '/default via/ {print $5}')" | \
    grep -E "^ *inet" | awk '{ print $2 }' | head -n1)"
PUBLIC_IPV6_ADDRESS_CIDR="$(ip addr show "$(ip -6 route | awk '/default via/ {print $5}')" 2>/dev/null | \
    grep -E "^ *inet6" | awk '{ print $2 }' | grep -v '^fe80' | head -n1)"
NETWORK_DEVICES_BY_ROLE="$(curl -Lsf https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/network/devices-by-role.sh | sh)"
cat <<EOF | tee .env
GATEWAY=$GATEWAY
IPV6_GATEWAY=$IPV6_GATEWAY
NETWORK_DEVICES_BY_ROLE="$NETWORK_DEVICES_BY_ROLE"
PUBLIC_IPV6_ADDRESS_CIDR=$PUBLIC_IPV6_ADDRESS_CIDR
PUBLIC_IP_ADDRESS_CIDR=$PUBLIC_IP_ADDRESS_CIDR
EOF
scp -P 2222 .env root@localhost:/root/
ssh -p 2222 root@localhost
