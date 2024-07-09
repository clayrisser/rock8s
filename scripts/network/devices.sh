#!/bin/sh

TEST_IP="8.8.8.8"

get_max_speed() {
    iface=$1
    link_modes=$(ethtool "$iface" 2>/dev/null | awk '/Advertised link modes:/ {flag=1} flag && /Advertised pause frame use:/ {flag=0} flag' | xargs)
    if echo "$link_modes" | grep -q "10000baseT/Full"; then
        echo "10G"
    elif echo "$link_modes" | grep -q "1000baseT/Full"; then
        echo "1G"
    elif echo "$link_modes" | grep -q "100baseT/Full"; then
        echo "100M"
    elif echo "$link_modes" | grep -q "10baseT/Full"; then
        echo "10M"
    fi
}

convert_speed() {
    speed=$1
    case "$speed" in
        "10G") echo 10000 ;;
        "1G") echo 1000 ;;
        "100M") echo 100 ;;
        "10M") echo 10 ;;
        *) echo 0 ;;
    esac
}

_LINKED_INTERFACES=""
_UNLINKED_INTERFACES=""
for _IFACE in $(ls /sys/class/net); do
    if [ -e "/sys/class/net/$_IFACE/device" ]; then
        _ALTNAME="$(ip link show "$_IFACE" | grep -E '^ *altname ' | sed 's|^ *altname *||g' | head -n1)"
        _LINK_STATUS=$(ethtool "$_IFACE" 2>/dev/null | grep "Link detected" | awk '{print $3}')
        _MAX_SPEED=$(get_max_speed "$_IFACE")
        _NUMERIC_SPEED=$(convert_speed "$_MAX_SPEED")
        _INTERNET_TAG=""
        _BRIDGE_PATH="/sys/class/net/$_IFACE/brport/bridge"
        if [ -d "$_BRIDGE_PATH" ]; then
            _BRIDGE=$(basename $(readlink $_BRIDGE_PATH))
            if [ ! -z "$_BRIDGE" ]; then
                if ping -I $_BRIDGE -c 1 -W 1 $TEST_IP > /dev/null 2>&1; then
                    _INTERNET_TAG="internet"
                fi
            else
                if ping -I $_IFACE -c 1 -W 1 $TEST_IP > /dev/null 2>&1; then
                    _INTERNET_TAG="internet"
                fi
            fi
        else
            if ping -I $_IFACE -c 1 -W 1 $TEST_IP > /dev/null 2>&1; then
                _INTERNET_TAG="internet"
            fi
        fi
        if [ "$_ALTNAME" != "" ]; then
            _IFACE="$_ALTNAME"
        fi
        if [ "$_LINK_STATUS" = "yes" ]; then
            value="$_IFACE=link:$_MAX_SPEED:$_INTERNET_TAG"
            _LINKED_INTERFACES="$_LINKED_INTERFACES $_NUMERIC_SPEED:$value"
        else
            value="$_IFACE=:$_MAX_SPEED:$_INTERNET_TAG"
            _UNLINKED_INTERFACES="$_UNLINKED_INTERFACES $_NUMERIC_SPEED:$value"
        fi
    fi
done
_SORTED_LINKED_INTERFACES=$(echo "$_LINKED_INTERFACES" | tr ' ' '\n' | sort -t: -k3,3r -k1,1nr -k2,2r | cut -d: -f2- | sort -t= -k1,1)
_SORTED_UNLINKED_INTERFACES=$(echo "$_UNLINKED_INTERFACES" | tr ' ' '\n' | sort -t: -k1,1nr -k2,2r | cut -d: -f2- | sort -t= -k1,1)
for _IFACE in $_SORTED_LINKED_INTERFACES; do
    echo "$_IFACE"
done
for _IFACE in $_SORTED_UNLINKED_INTERFACES; do
    echo "$_IFACE"
done
