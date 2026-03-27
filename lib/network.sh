#!/bin/sh

set -e

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
    start_octet4="$(((octet4 + start_ipv4_num) % 256))"
    start_octet3="$(((octet3 + ((octet4 + start_ipv4_num) / 256)) % 256))"
    start_octet2="$(((octet2 + ((octet3 + ((octet4 + start_ipv4_num) / 256)) / 256)) % 256))"
    start_octet1="$((octet1 + ((octet2 + ((octet3 + ((octet4 + start_ipv4_num) / 256)) / 256)) / 256)))"
    end_octet4="$(((octet4 + end_ipv4_num) % 256))"
    end_octet3="$(((octet3 + ((octet4 + end_ipv4_num) / 256)) % 256))"
    end_octet2="$(((octet2 + ((octet3 + ((octet4 + end_ipv4_num) / 256)) / 256)) % 256))"
    end_octet1="$((octet1 + ((octet2 + ((octet3 + ((octet4 + end_ipv4_num) / 256)) / 256)) / 256)))"
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

get_lan_ipv4_subnet() {
    if [ -n "$_LAN_IPV4_SUBNET" ]; then
        echo "$_LAN_IPV4_SUBNET"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _LAN_IPV4_SUBNET="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.ipv4.subnet // ""')"
    if [ -z "$_LAN_IPV4_SUBNET" ]; then
        fail ".network.lan.ipv4.subnet not found in config.yaml"
    fi
    echo "$_LAN_IPV4_SUBNET"
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
