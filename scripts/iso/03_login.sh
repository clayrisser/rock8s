#!/bin/sh

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
cat <<EOF > .env
GATEWAY=$GATEWAY
PUBLIC_IP_ADDRESS_CIDR=$PUBLIC_IP_ADDRESS_CIDR
INTERFACE=$INTERFACE
EOF
scp -P 2222 .env root@localhost:/root/
ssh -p 2222 root@localhost
