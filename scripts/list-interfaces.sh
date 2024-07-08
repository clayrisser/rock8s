#!/bin/sh

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

sudo true
linked_interfaces=""
unlinked_interfaces=""
for iface in $(ls /sys/class/net); do
    if [ -e "/sys/class/net/$iface/device" ]; then
        sudo ip link set "$iface" up
        link_status=$(ethtool "$iface" 2>/dev/null | grep "Link detected" | awk '{print $3}')
        max_speed=$(get_max_speed "$iface")
        numeric_speed=$(convert_speed "$max_speed")
        if [ "$link_status" = "yes" ]; then
            value="$iface=link:$max_speed"
            linked_interfaces="$linked_interfaces $numeric_speed:$value"
        else
            value="$iface=:$max_speed"
            unlinked_interfaces="$unlinked_interfaces $numeric_speed:$value"
        fi
    fi
done
sorted_linked_interfaces=$(echo "$linked_interfaces" | tr ' ' '\n' | sort -t: -k1 -nr | cut -d: -f2- | sort -t= -k1,1)
sorted_unlinked_interfaces=$(echo "$unlinked_interfaces" | tr ' ' '\n' | sort -t: -k1 -nr | cut -d: -f2- | sort -t= -k1,1)
for iface in $sorted_linked_interfaces; do
    echo "$iface"
done
for iface in $sorted_unlinked_interfaces; do
    echo "$iface"
done
