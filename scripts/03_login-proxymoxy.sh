#!/bin/sh

INTERFACE="$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/ .*//")"
INTERFACE_ALTNAME="$(ip addr show $INTERFACE | grep -E "^ *altname" | awk '{ print $2 }' | head -n1)"
IP_ADDRESS_CIDR="$(ip addr show $INTERFACE | grep -E "^ *inet" | awk '{ print $2 }' | head -n1)"
GATEWAY="$(ip route | grep default | awk '{ print $3 }')"
cat <<EOF > .env
GATEWAY=$GATEWAY
IP_ADDRESS_CIDR=$IP_ADDRESS_CIDR
INTERFACE=$INTERFACE
INTERFACE_ALTNAME=$INTERFACE_ALTNAME
EOF
scp -P 2222 .env root@localhost:/root/
ssh -p 2222 root@localhost
