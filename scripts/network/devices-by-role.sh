#!/bin/sh

_NETWORK_DEVICES_SH="$(dirname "$0")/devices.sh"
if [ -f "$_NETWORK_DEVICES_SH" ]; then
    _NETWORK_DEVICES="$(sh "$_NETWORK_DEVICES_SH")"
else
    _NETWORK_DEVICES="$(curl -Lsf https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/network/devices.sh | sh)"
fi
_ALL_10G=""
_LINK_10G=""
_NO_LINK_10G=""
_LINK_1G=""
_NO_LINK_1G=""
_OTHER_INTERFACES=""
for line in $(echo "$_NETWORK_DEVICES"); do
    case "$line" in
    *=link:10G) _LINK_10G="$_LINK_10G ${line%%=*}"; _ALL_10G="$_ALL_10G ${line%%=*}" ;;
    *:10G) _NO_LINK_10G="$_NO_LINK_10G ${line%%=*}"; _ALL_10G="$_ALL_10G ${line%%=*}" ;;
    *=link:1G) _LINK_1G="$_LINK_1G ${line%%=*}" ;;
    *:1G) _NO_LINK_1G="$_NO_LINK_1G ${line%%=*}" ;;
    *) _OTHER_INTERFACES="$_OTHER_INTERFACES ${line%%=*}" ;;
    esac
done
_ALL_INTERFACES="$_LINK_10G $_NO_LINK_10G $_LINK_1G $_NO_LINK_1G $_OTHER_INTERFACES"
set -- $_ALL_INTERFACES
set -- $_ALL_10G
if [ "$#" -ge 2 ]; then
    _UPLINK=$1
    _CEPH=$2
else
    set -- $_LINK_10G $_NO_LINK_10G
    _UPLINK=$1
    _CEPH=$2
fi
_PRIVATE=""
for device in $_NO_LINK_10G $_NO_LINK_1G; do
    if [ "$device" != "$_CEPH" ]; then
        _PRIVATE=$device
        break
    fi
done
echo "uplink:$(echo "$_NETWORK_DEVICES" | grep -E "^$_UPLINK=")"
if [ -n "$_PRIVATE" ]; then
    echo "private:$(echo "$_NETWORK_DEVICES" | grep -E "^$_PRIVATE=")"
fi
if [ -n "$_CEPH" ]; then
    echo "ceph:$(echo "$_NETWORK_DEVICES" | grep -E "^$_CEPH=")"
fi
