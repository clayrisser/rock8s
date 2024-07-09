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

linked_interfaces=""
unlinked_interfaces=""
for _IFACE in $(ls /sys/class/net); do
    if [ -e "/sys/class/net/$_IFACE/device" ]; then
        link_status=$(ethtool "$_IFACE" 2>/dev/null | grep "Link detected" | awk '{print $3}')
        max_speed=$(get_max_speed "$_IFACE")
        numeric_speed=$(convert_speed "$max_speed")
        internet_tag=""
        _BRIDGE_PATH="/sys/class/net/$_IFACE/brport/bridge"
        if [ -d "$_BRIDGE_PATH" ]; then
            _BRIDGE=$(basename $(readlink $_BRIDGE_PATH))
            if [ ! -z "$_BRIDGE" ]; then
                if ping -I $_BRIDGE -c 1 -W 1 $TEST_IP > /dev/null 2>&1; then
                    internet_tag="internet"
                fi
            else
                if ping -I $_IFACE -c 1 -W 1 $TEST_IP > /dev/null 2>&1; then
                    internet_tag="internet"
                fi
            fi
        else
            if ping -I $_IFACE -c 1 -W 1 $TEST_IP > /dev/null 2>&1; then
                internet_tag="internet"
            fi
        fi
        if [ "$link_status" = "yes" ]; then
            value="$_IFACE=link:$max_speed:$internet_tag"
            linked_interfaces="$linked_interfaces $numeric_speed:$value"
        else
            value="$_IFACE=:$max_speed:$internet_tag"
            unlinked_interfaces="$unlinked_interfaces $numeric_speed:$value"
        fi
    fi
done
sorted_linked_interfaces=$(echo "$linked_interfaces" | tr ' ' '\n' | sort -t: -k1 -nr | cut -d: -f2- | sort -t= -k1,1)
sorted_unlinked_interfaces=$(echo "$unlinked_interfaces" | tr ' ' '\n' | sort -t: -k1 -nr | cut -d: -f2- | sort -t= -k1,1)
for _IFACE in $sorted_linked_interfaces; do
    echo "$_IFACE"
done
for _IFACE in $sorted_unlinked_interfaces; do
    echo "$_IFACE"
done
