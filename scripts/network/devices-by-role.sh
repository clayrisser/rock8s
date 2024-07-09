#!/bin/sh

_NETWORK_DEVICES_SH="$(dirname "$0")/devices.sh"
if [ -f "$_NETWORK_DEVICES_SH" ]; then
    _NETWORK_DEVICES="$(sh "$_NETWORK_DEVICES_SH")"
else
    _NETWORK_DEVICES="$(curl -Lsf https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/network/devices.sh | sh)"
fi
_LINK_10G=""
_NO_LINK_10G=""
_LINK_1G=""
_NO_LINK_1G=""
_LINK_10G_INTERNET=""
_LINK_1G_INTERNET=""
_OTHER_INTERFACES=""
for line in $(echo "$_NETWORK_DEVICES"); do
    case "$line" in
    *=link:10G:internet) _LINK_10G_INTERNET="$_LINK_10G_INTERNET ${line%%=*}" ;;
    *=link:10G:) _LINK_10G="$_LINK_10G ${line%%=*}" ;;
    *:10G:) _NO_LINK_10G="$_NO_LINK_10G ${line%%=*}" ;;
    *=link:1G:internet) _LINK_1G_INTERNET="$_LINK_1G_INTERNET ${line%%=*}" ;;
    *=link:1G:) _LINK_1G="$_LINK_1G ${line%%=*}" ;;
    *:1G:) _NO_LINK_1G="$_NO_LINK_1G ${line%%=*}" ;;
    *) _OTHER_INTERFACES="$_OTHER_INTERFACES ${line%%=*}" ;;
    esac
done
_ALL_INTERFACES="$_LINK_10G $_NO_LINK_10G $_LINK_1G $_NO_LINK_1G $_OTHER_INTERFACES"
echo _LINK_10G_INTERNET: $_LINK_10G_INTERNET
echo _LINK_1G_INTERNET: $_LINK_1G_INTERNET
echo _LINK_10G: $_LINK_10G
echo _LINK_1G: $_LINK_1G
echo _NO_LINK_10G: $_NO_LINK_10G
echo _NO_LINK_1G: $_NO_LINK_1G
echo _OTHER_INTERFACES: $_OTHER_INTERFACES
echo _ALL_INTERFACES: $_ALL_INTERFACES
_UPLINK=""
_CEPH=""
_PRIVATE=""
for device in $_LINK_10G_INTERNET $_LINK_1G_INTERNET; do
    _UPLINK=$device
    break
done
for device in $_LINK_10G $_NO_LINK_10G; do
    if [ "$device" != "$_UPLINK" ]; then
        _CEPH=$device
        break
    fi
done
for device in $_LINK_10G $_LINK_1G $_NO_LINK_10G $_NO_LINK_1G; do
    if [ "$device" != "$_CEPH" ] && [ "$device" != "$_UPLINK" ]; then
        _PRIVATE=$device
        break
    fi
done
if [ "$_CEPH" = "" ]; then
    for device in $_LINK_10G $_LINK_1G $_NO_LINK_10G $_NO_LINK_1G; do
        if [ "$device" != "$_PRIVATE" ] && [ "$device" != "$_UPLINK" ]; then
            _CEPH=$device
            break
        fi
    done
fi
if [ "$_UPLINK" != "" ]; then
    echo "uplink:$(echo "$_NETWORK_DEVICES" | grep -m 1 -E "^$_UPLINK=")"
fi
if [ "$_PRIVATE" != "" ]; then
    echo "private:$(echo "$_NETWORK_DEVICES" | grep -m 1 -E "^$_PRIVATE=")"
fi
if [ "$_CEPH" != "" ]; then
    echo "ceph:$(echo "$_NETWORK_DEVICES" | grep -m 1 -E "^$_CEPH=")"
fi
