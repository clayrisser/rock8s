#!/bin/sh

GATEWAY="$(ip route | grep default | awk '{ print $3 }')"
PUBLIC_IP_ADDRESS_CIDR="$(ip addr show "$(ip route | awk '/default via/ {print $5}')" | \
    grep -E "^ *inet" | awk '{ print $2 }' | head -n1)"
NETWORK_DEVICES_BY_ROLE="$(curl -Lsf https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/list-network-devices-by-role.sh | sh)"
cat <<EOF | tee .env
GATEWAY=$GATEWAY
PUBLIC_IP_ADDRESS_CIDR=$PUBLIC_IP_ADDRESS_CIDR
NETWORK_DEVICES_BY_ROLE="$NETWORK_DEVICES_BY_ROLE"
EOF
scp -P 2222 .env root@localhost:/root/
ssh -p 2222 root@localhost
