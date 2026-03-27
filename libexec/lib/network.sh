#!/bin/sh

set -e

calculate_next_ipv4() {
    ipv4="$1"
    increment="${2:-1}"
    if echo "$ipv4" | grep -q '/'; then
        ipv4="$(echo "$ipv4" | cut -d'/' -f1)"
    fi
    if echo "$ipv4" | grep -q '-'; then
        ipv4="$(echo "$ipv4" | cut -d'-' -f1)"
    fi
    octet1="$(echo "$ipv4" | cut -d'.' -f1)"
    octet2="$(echo "$ipv4" | cut -d'.' -f2)"
    octet3="$(echo "$ipv4" | cut -d'.' -f3)"
    octet4="$(echo "$ipv4" | cut -d'.' -f4)"
    new_octet4=$((octet4 + increment))
    new_octet3=$octet3
    new_octet2=$octet2
    new_octet1=$octet1
    if [ $new_octet4 -gt 255 ]; then
        new_octet3=$((octet3 + (new_octet4 / 256)))
        new_octet4=$((new_octet4 % 256))
        if [ $new_octet3 -gt 255 ]; then
            new_octet2=$((octet2 + (new_octet3 / 256)))
            new_octet3=$((new_octet3 % 256))
            if [ $new_octet2 -gt 255 ]; then
                new_octet1=$((octet1 + (new_octet2 / 256)))
                new_octet2=$((new_octet2 % 256))
                if [ $new_octet1 -gt 255 ]; then
                    _fail "ip address overflow"
                fi
            fi
        fi
    fi
    echo "${new_octet1}.${new_octet2}.${new_octet3}.${new_octet4}"
}

calculate_previous_ipv4() {
    ipv4="$1"
    offset="$2"
    echo "$ipv4" | awk -F. -v offset="$offset" '{
        last = $4 - offset
        if (last < 0) {
            last = 256 + last
            $3 = $3 - 1
        }
        print $1"."$2"."$3"."last
    }'
}

calculate_first_ipv4() {
    input="$1"
    if echo "$input" | grep -q '/'; then
        echo "$input" | awk -F'[./]' '{
            print $1"."$2"."$3".1"
        }'
    elif echo "$input" | grep -q '-'; then
        echo "$input" | awk -F'[-]' '{
            print $1
        }'
    else
        echo "$input"
    fi
}

calculate_last_ipv4() {
    input="$1"
    if echo "$input" | grep -q '/'; then
        echo "$input" | awk -F'[./]' '{
            mask=$5
            bits = 32-mask
            size = 2^bits
            network = ($1 * 2^24) + ($2 * 2^16) + ($3 * 2^8) + $4
            last = network + size - 2
            print int(last/2^24)"."int((last%2^24)/2^16)"."int((last%2^16)/2^8)"."int(last%2^8)
        }'
    elif echo "$input" | grep -q '-'; then
        echo "$input" | awk -F'[-]' '{
            print $2
        }'
    else
        echo "$input"
    fi
}

_resolve_hostname() {
    hostname="$1"
    type="$2"
    if [ -z "$hostname" ]; then
        return
    fi
    if echo "$hostname" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "$hostname"
    elif echo "$hostname" | grep -qE '^[0-9a-fA-F:]+$'; then
        echo "$hostname"
    else
        if [ "$type" = "ipv4" ] || [ -z "$type" ]; then
            ipv4=$(host "$hostname" | grep 'has address' | head -n1 | awk '{print $NF}')
            if [ -n "$ipv4" ]; then
                echo "$ipv4"
                return
            fi
        fi
        if [ "$type" = "ipv6" ] || [ -z "$type" ]; then
            ipv6=$(host "$hostname" | grep 'has IPv6 address' | head -n1 | awk '{print $NF}')
            if [ -n "$ipv6" ]; then
                echo "$ipv6"
                return
            fi
        fi
    fi
}

calculate_metallb() {
    subnet="$1"
    subnet_prefix="$(echo "$subnet" | cut -d'/' -f1)"
    subnet_mask="$(echo "$subnet" | cut -d'/' -f2)"
    IFS='.'
    set -- $(echo "$subnet_prefix")
    octet1="$1"
    octet2="$2"
    octet3="$3"
    octet4="$4"
    unset IFS
    pow_val=$((32 - subnet_mask))
    total_ipv4s=1
    i=0
    while [ $i -lt $pow_val ]; do
        total_ipv4s=$((total_ipv4s * 2))
        i=$((i + 1))
    done
    metallb_count="$((total_ipv4s / 20))"
    [ "$metallb_count" -lt 10 ] && metallb_count=10
    [ "$metallb_count" -gt 100 ] && metallb_count=100
    if [ "$metallb_count" -ge "$total_ipv4s" ]; then
        metallb_count="$((total_ipv4s / 2))"
        [ "$metallb_count" -lt 5 ] && metallb_count=5
    fi
    start_ipv4_num="$((total_ipv4s - metallb_count - 1))"
    end_ipv4_num="$((total_ipv4s - 2))"
    start_octet4="$(( (octet4 + start_ipv4_num) % 256 ))"
    start_octet3="$(( (octet3 + ((octet4 + start_ipv4_num) / 256)) % 256 ))"
    start_octet2="$(( (octet2 + ((octet3 + ((octet4 + start_ipv4_num) / 256)) / 256)) % 256 ))"
    start_octet1="$(( octet1 + ((octet2 + ((octet3 + ((octet4 + start_ipv4_num) / 256)) / 256)) / 256) ))"
    end_octet4="$(( (octet4 + end_ipv4_num) % 256 ))"
    end_octet3="$(( (octet3 + ((octet4 + end_ipv4_num) / 256)) % 256 ))"
    end_octet2="$(( (octet2 + ((octet3 + ((octet4 + end_ipv4_num) / 256)) / 256)) % 256 ))"
    end_octet1="$(( octet1 + ((octet2 + ((octet3 + ((octet4 + end_ipv4_num) / 256)) / 256)) / 256) ))"
    start_ipv4="${start_octet1}.${start_octet2}.${start_octet3}.${start_octet4}"
    end_ipv4="${end_octet1}.${end_octet2}.${end_octet3}.${end_octet4}"
    metallb_range="${start_ipv4}-${end_ipv4}"
    if [ -z "$metallb_range" ] || [ "$start_octet1" -gt 255 ] || [ "$end_octet1" -gt 255 ]; then
        if [ "$subnet_mask" -le "8" ]; then
            network_base="$(echo "$subnet_prefix" | cut -d'.' -f1)"
            metallb_range="${network_base}.255.255.200-${network_base}.255.255.254"
        elif [ "$subnet_mask" -le "16" ]; then
            network_base="$(echo "$subnet_prefix" | cut -d'.' -f1-2)"
            metallb_range="${network_base}.255.200-${network_base}.255.254"
        elif [ "$subnet_mask" -le "24" ]; then
            network_base="$(echo "$subnet_prefix" | cut -d'.' -f1-3)"
            metallb_range="${network_base}.200-${network_base}.254"
        else
            ipv4_base="$(echo "$subnet_prefix" | cut -d'.' -f1-3)"
            last_octet="$(echo "$subnet_prefix" | cut -d'.' -f4)"
            pow_val=$((32 - subnet_mask))
            max_pow=1
            i=0
            while [ $i -lt $pow_val ]; do
                max_pow=$((max_pow * 2))
                i=$((i + 1))
            done
            max_ipv4="$((max_pow + last_octet - 2))"
            min_ipv4="$((max_ipv4 - 10 > last_octet ? max_ipv4 - 10 : last_octet + 1))"
            metallb_range="${ipv4_base}.${min_ipv4}-${ipv4_base}.${max_ipv4}"
        fi
    fi
    echo "$metallb_range"
}

get_network_mtu() {
    if [ -n "$_NETWORK_MTU" ]; then
        echo "$_NETWORK_MTU"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _NETWORK_MTU="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.mtu // "1500"')"
    echo "$_NETWORK_MTU"
}

get_enable_network_dualstack() {
    if [ -n "$_ENABLE_NETWORK_DUALSTACK" ]; then
        echo "$_ENABLE_NETWORK_DUALSTACK"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    ipv6_subnet="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.ipv6.subnet // ""')"
    if [ -n "$ipv6_subnet" ]; then
        _ENABLE_NETWORK_DUALSTACK="1"
    else
        _ENABLE_NETWORK_DUALSTACK="0"
    fi
    echo "$_ENABLE_NETWORK_DUALSTACK"
}

get_lan_metallb() {
    if [ -n "$_LAN_METALLB" ]; then
        echo "$_LAN_METALLB"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _LAN_METALLB="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.metallb // ""')"
    if [ -z "$_LAN_METALLB" ]; then
        _LAN_METALLB="$(calculate_metallb "$(get_lan_ipv4_subnet)")"
    fi
    echo "$_LAN_METALLB"
}

get_lan_ingress_ipv4() {
    if [ -n "$_LAN_INGRESS_IPV4" ]; then
        echo "$_LAN_INGRESS_IPV4"
        return
    fi
    _LAN_METALLB="$(get_lan_metallb)"
    _LAN_INGRESS_IPV4="$(echo "$_LAN_METALLB" | cut -d'-' -f1)"
    echo "$_LAN_INGRESS_IPV4"
}
