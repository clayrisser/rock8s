#!/bin/sh

_LIST_NETWORK_DEVICES_SH="$(dirname "$0")/list-network-devices.sh"
if [ -f "$_LIST_NETWORK_DEVICES_SH" ]; then
    _NETWORK_DEVICES="$(sh "$_LIST_NETWORK_DEVICES_SH")"
else
    _NETWORK_DEVICES="$(curl -Lsf https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/list-network-devices.sh | sh)"
fi
_ALL_10G=""
_LINK_10G=""
_NO_LINK_10G=""
_OTHER_INTERFACES=""
for line in $(echo "$_NETWORK_DEVICES"); do
    case "$line" in
    *=link:10G) _LINK_10G="$_LINK_10G ${line%%=*}"; _ALL_10G="$_ALL_10G ${line%%=*}" ;;
    *:10G) _NO_LINK_10G="$_NO_LINK_10G ${line%%=*}"; _ALL_10G="$_ALL_10G ${line%%=*}" ;;
    *) _OTHER_INTERFACES="$_OTHER_INTERFACES ${line%%=*}" ;;
    esac
done
_ALL_INTERFACES="$_LINK_10G $_NO_LINK_10G $_OTHER_INTERFACES"
set -- $_ALL_INTERFACES
_PRIVATE=$(eval echo \${$#})
set -- $_ALL_10G
if [ "$#" -ge 2 ]; then
    _UPLINK=$1
    _CEPH=$2
else
    set -- $_LINK_10G $_NO_LINK_10G
    _UPLINK=$1
    _CEPH=$2
fi
echo "uplink=$(echo "$_NETWORK_DEVICES" | grep -E "^$_UPLINK=")"
echo "private=$(echo "$_NETWORK_DEVICES" | grep -E "^$_PRIVATE=")"
echo "ceph=$(echo "$_NETWORK_DEVICES" | grep -E "^$_CEPH=")"
