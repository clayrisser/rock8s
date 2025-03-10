#!/bin/sh

_calculate_next_ipv4() {
    _IPV4="$1"
    _INCREMENT="${2:-1}"
    if echo "$_IPV4" | grep -q '/'; then
        _IPV4="$(echo "$_IPV4" | cut -d'/' -f1)"
    fi
    if echo "$_IPV4" | grep -q '-'; then
        _IPV4="$(echo "$_IPV4" | cut -d'-' -f1)"
    fi
    _OCTET1="$(echo "$_IPV4" | cut -d'.' -f1)"
    _OCTET2="$(echo "$_IPV4" | cut -d'.' -f2)"
    _OCTET3="$(echo "$_IPV4" | cut -d'.' -f3)"
    _OCTET4="$(echo "$_IPV4" | cut -d'.' -f4)"
    _NEW_OCTET4=$((_OCTET4 + _INCREMENT))
    _NEW_OCTET3=$_OCTET3
    _NEW_OCTET2=$_OCTET2
    _NEW_OCTET1=$_OCTET1
    if [ $_NEW_OCTET4 -gt 255 ]; then
        _NEW_OCTET3=$((_OCTET3 + (_NEW_OCTET4 / 256)))
        _NEW_OCTET4=$((_NEW_OCTET4 % 256))
        if [ $_NEW_OCTET3 -gt 255 ]; then
            _NEW_OCTET2=$((_OCTET2 + (_NEW_OCTET3 / 256)))
            _NEW_OCTET3=$((_NEW_OCTET3 % 256))
            if [ $_NEW_OCTET2 -gt 255 ]; then
                _NEW_OCTET1=$((_OCTET1 + (_NEW_OCTET2 / 256)))
                _NEW_OCTET2=$((_NEW_OCTET2 % 256))
                if [ $_NEW_OCTET1 -gt 255 ]; then
                    _error "ip address overflow"
                    return 1
                fi
            fi
        fi
    fi
    echo "${_NEW_OCTET1}.${_NEW_OCTET2}.${_NEW_OCTET3}.${_NEW_OCTET4}"
}

_calculate_previous_ipv4() {
    _IPV4="$1"
    _OFFSET="$2"
    echo "$_IPV4" | awk -F. -v offset="$_OFFSET" '{
        last = $4 - offset
        if (last < 0) {
            last = 256 + last
            $3 = $3 - 1
        }
        print $1"."$2"."$3"."last
    }'
}

_calculate_first_ipv4() {
    _INPUT="$1"
    if echo "$_INPUT" | grep -q '/'; then
        echo "$_INPUT" | awk -F'[./]' '{
            print $1"."$2"."$3".1"
        }'
    elif echo "$_INPUT" | grep -q '-'; then
        echo "$_INPUT" | awk -F'[-]' '{
            print $1
        }'
    else
        echo "$_INPUT"
    fi
}

_calculate_last_ipv4() {
    _INPUT="$1"
    if echo "$_INPUT" | grep -q '/'; then
        echo "$_INPUT" | awk -F'[./]' '{
            mask=$5
            bits = 32-mask
            size = 2^bits
            network = ($1 * 2^24) + ($2 * 2^16) + ($3 * 2^8) + $4
            last = network + size - 2
            print int(last/2^24)"."int((last%2^24)/2^16)"."int((last%2^16)/2^8)"."int(last%2^8)
        }'
    elif echo "$_INPUT" | grep -q '-'; then
        echo "$_INPUT" | awk -F'[-]' '{
            print $2
        }'
    else
        echo "$_INPUT"
    fi
}

_resolve_hostname() {
    _HOSTNAME="$1"
    if [ -z "$_HOSTNAME" ]; then
        return 0
    fi
    if echo "$_HOSTNAME" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "$_HOSTNAME"
    elif echo "$_HOSTNAME" | grep -qE '^[0-9a-fA-F:]+$'; then
        echo "$_HOSTNAME"
    else
        _IPV4=$(host "$_HOSTNAME" | grep 'has address' | head -n1 | awk '{print $NF}')
        if [ -n "$_IPV4" ]; then
            echo "$_IPV4"
            return
        fi
        _IPV6=$(host "$_HOSTNAME" | grep 'has IPv6 address' | head -n1 | awk '{print $NF}')
        if [ -n "$_IPV6" ]; then
            echo "$_IPV6"
            return
        fi
        return 1
    fi
}

_calculate_metallb() {
    _SUBNET="$1"
    _SUBNET_PREFIX="$(echo "$_SUBNET" | cut -d'/' -f1)"
    _SUBNET_MASK="$(echo "$_SUBNET" | cut -d'/' -f2)"
    IFS='.'
    set -- $(echo "$_SUBNET_PREFIX")
    _OCTET1="$1"
    _OCTET2="$2"
    _OCTET3="$3"
    _OCTET4="$4"
    unset IFS
    _POW_VAL=$((32 - _SUBNET_MASK))
    _TOTAL_IPV4S=1
    _i=0
    while [ $_i -lt $_POW_VAL ]; do
        _TOTAL_IPV4S=$((_TOTAL_IPV4S * 2))
        _i=$((_i + 1))
    done
    _METALLB_COUNT="$((_TOTAL_IPV4S / 20))"
    [ "$_METALLB_COUNT" -lt 10 ] && _METALLB_COUNT=10
    [ "$_METALLB_COUNT" -gt 100 ] && _METALLB_COUNT=100
    if [ "$_METALLB_COUNT" -ge "$_TOTAL_IPV4S" ]; then
        _METALLB_COUNT="$((_TOTAL_IPV4S / 2))"
        [ "$_METALLB_COUNT" -lt 5 ] && _METALLB_COUNT=5
    fi
    _START_IPV4_NUM="$((_TOTAL_IPV4S - _METALLB_COUNT - 1))"
    _END_IPV4_NUM="$((_TOTAL_IPV4S - 2))"
    _START_OCTET4="$(( (_OCTET4 + _START_IPV4_NUM) % 256 ))"
    _START_OCTET3="$(( (_OCTET3 + ((_OCTET4 + _START_IPV4_NUM) / 256)) % 256 ))"
    _START_OCTET2="$(( (_OCTET2 + ((_OCTET3 + ((_OCTET4 + _START_IPV4_NUM) / 256)) / 256)) % 256 ))"
    _START_OCTET1="$(( _OCTET1 + ((_OCTET2 + ((_OCTET3 + ((_OCTET4 + _START_IPV4_NUM) / 256)) / 256)) / 256) ))"
    _END_OCTET4="$(( (_OCTET4 + _END_IPV4_NUM) % 256 ))"
    _END_OCTET3="$(( (_OCTET3 + ((_OCTET4 + _END_IPV4_NUM) / 256)) % 256 ))"
    _END_OCTET2="$(( (_OCTET2 + ((_OCTET3 + ((_OCTET4 + _END_IPV4_NUM) / 256)) / 256)) % 256 ))"
    _END_OCTET1="$(( _OCTET1 + ((_OCTET2 + ((_OCTET3 + ((_OCTET4 + _END_IPV4_NUM) / 256)) / 256)) / 256) ))"
    _START_IPV4="${_START_OCTET1}.${_START_OCTET2}.${_START_OCTET3}.${_START_OCTET4}"
    _END_IPV4="${_END_OCTET1}.${_END_OCTET2}.${_END_OCTET3}.${_END_OCTET4}"
    _METALLB_RANGE="${_START_IPV4}-${_END_IPV4}"
    if [ -z "$_METALLB_RANGE" ] || [ "$_START_OCTET1" -gt 255 ] || [ "$_END_OCTET1" -gt 255 ]; then
        if [ "$_SUBNET_MASK" -le "8" ]; then
            _NETWORK_BASE="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f1)"
            _METALLB_RANGE="${_NETWORK_BASE}.255.255.200-${_NETWORK_BASE}.255.255.254"
        elif [ "$_SUBNET_MASK" -le "16" ]; then
            _NETWORK_BASE="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f1-2)"
            _METALLB_RANGE="${_NETWORK_BASE}.255.200-${_NETWORK_BASE}.255.254"
        elif [ "$_SUBNET_MASK" -le "24" ]; then
            _NETWORK_BASE="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f1-3)"
            _METALLB_RANGE="${_NETWORK_BASE}.200-${_NETWORK_BASE}.254"
        else
            _IPV4_BASE="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f1-3)"
            _LAST_OCTET="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f4)"
            _POW_VAL=$((32 - _SUBNET_MASK))
            _MAX_POW=1
            _i=0
            while [ $_i -lt $_POW_VAL ]; do
                _MAX_POW=$((_MAX_POW * 2))
                _i=$((_i + 1))
            done
            _MAX_IPV4="$((_MAX_POW + _LAST_OCTET - 2))"
            _MIN_IPV4="$((_MAX_IPV4 - 10 > _LAST_OCTET ? _MAX_IPV4 - 10 : _LAST_OCTET + 1))"
            _METALLB_RANGE="${_IPV4_BASE}.${_MIN_IPV4}-${_IPV4_BASE}.${_MAX_IPV4}"
        fi
    fi
    echo "$_METALLB_RANGE"
}

_get_lan_ipv4_subnet() {
    if [ -n "$_LAN_IPV4_SUBNET" ]; then
        echo "$_LAN_IPV4_SUBNET"
        return 0
    fi
    _LAN_IPV4_SUBNET="$(_get_config_json | jq -r '.network.lan.ipv4.subnet // ""')"
    if [ -z "$_LAN_IPV4_SUBNET" ] || [ "$_LAN_IPV4_SUBNET" = "null" ]; then
        _fail ".network.lan.ipv4.subnet not found in config.yaml"
    fi
    echo "$_LAN_IPV4_SUBNET"
}

_get_lan_ipv6_subnet() {
    if [ -n "$_LAN_IPV6_SUBNET" ]; then
        echo "$_LAN_IPV6_SUBNET"
        return 0
    fi
    _LAN_IPV6_SUBNET="$(_get_config_json | jq -r '.network.lan.ipv6.subnet // ""')"
    if [ -z "$_LAN_IPV6_SUBNET" ] || [ "$_LAN_IPV6_SUBNET" = "null" ]; then
        _LAN_IPV4_NETWORK="$(_get_lan_ipv4_subnet | cut -d'/' -f1)"
        _LAST_NONZERO_OCTET=""
        _OCTET_COUNT=1
        for _OCTET in $(echo "$_LAN_IPV4_NETWORK" | tr '.' ' '); do
            if [ "$_OCTET" != "0" ]; then
                _LAST_NONZERO_OCTET="$_OCTET"
                _LAST_NONZERO_POSITION="$_OCTET_COUNT"
            fi
            _OCTET_COUNT=$((_OCTET_COUNT + 1))
        done
        if [ "$_LAST_NONZERO_OCTET" -gt 99 ]; then
            _PREFIX="$(printf '%02x' "$_LAST_NONZERO_OCTET")"
        else
            _PREFIX="$_LAST_NONZERO_OCTET"
        fi
        _LAN_IPV6_SUBNET="fd${_PREFIX}::/64"
    fi
    echo "$_LAN_IPV6_SUBNET"
}

_get_pfsense_primary_hostname() {
    if [ -n "$_PFSENSE_PRIMARY_HOSTNAME" ]; then
        echo "$_PFSENSE_PRIMARY_HOSTNAME"
        return 0
    fi
    _PFSENSE_PRIMARY_HOSTNAME="$(_get_config_json | jq -r '.pfsense[0].hostnames[0] // ""')"
    if [ -z "$_PFSENSE_PRIMARY_HOSTNAME" ] || [ "$_PFSENSE_PRIMARY_HOSTNAME" = "null" ]; then
        _fail ".pfsense[0].hostnames[0] not found in config.yaml"
    fi
    echo "$_PFSENSE_PRIMARY_HOSTNAME"
}

_get_pfsense_secondary_hostname() {
    if [ -n "$_PFSENSE_SECONDARY_HOSTNAME" ]; then
        echo "$_PFSENSE_SECONDARY_HOSTNAME"
        return 0
    fi
    _PFSENSE_SECONDARY_HOSTNAME="$(_get_config_json | jq -r '.pfsense[0].hostnames[1] // ""')"
    echo "$_PFSENSE_SECONDARY_HOSTNAME"
}

_get_pfsense_shared_hostname() {
    if [ -n "$_PFSENSE_SHARED_HOSTNAME" ]; then
        echo "$_PFSENSE_SHARED_HOSTNAME"
        return 0
    fi
    _PFSENSE_SHARED_HOSTNAME="$(_get_config_json | jq -r '.pfsense[0].hostnames[2] // ""')"
    echo "$_PFSENSE_SHARED_HOSTNAME"
}

_get_pfsense_shared_wan_ipv4() {
    if [ -n "$_PFSENSE_SHARED_WAN_IPV4" ]; then
        echo "$_PFSENSE_SHARED_WAN_IPV4"
        return 0
    fi
    _PFSENSE_SHARED_WAN_IPV4="$(_resolve_hostname "$(_get_pfsense_shared_hostname)")"
    echo "$_PFSENSE_SHARED_WAN_IPV4"
}

_get_pfsense_primary_lan_ipv4() {
    if [ -n "$_PFSENSE_PRIMARY_LAN_IPV4" ]; then
        echo "$_PFSENSE_PRIMARY_LAN_IPV4"
        return 0
    fi
    _LAN_IPV4_NETWORK="$(_get_lan_ipv4_subnet | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_LAN_IPV4="$(_calculate_next_ipv4 "$_LAN_IPV4_NETWORK" 2)"
    echo "$_PFSENSE_PRIMARY_LAN_IPV4"
}

_get_pfsense_secondary_lan_ipv4() {
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV4" ]; then
        echo "$_PFSENSE_SECONDARY_LAN_IPV4"
        return 0
    fi
    _LAN_IPV4_NETWORK="$(_get_lan_ipv4_subnet | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_LAN_IPV4="$(_calculate_next_ipv4 "$_LAN_IPV4_NETWORK" 3)"
    echo "$_PFSENSE_SECONDARY_LAN_IPV4"
}

_get_pfsense_shared_lan_ipv4() {
    if [ -n "$_PFSENSE_SHARED_LAN_IPV4" ]; then
        echo "$_PFSENSE_SHARED_LAN_IPV4"
        return 0
    fi
    _PFSENSE_SHARED_LAN_IPV4="$(_calculate_last_ipv4 "$(_get_lan_ipv4_subnet)")"
    echo "$_PFSENSE_SHARED_LAN_IPV4"
}

_get_pfsense_primary_lan_ipv6() {
    if [ -n "$_PFSENSE_PRIMARY_LAN_IPV6" ]; then
        echo "$_PFSENSE_PRIMARY_LAN_IPV6"
        return 0
    fi
    _LAN_IPV6_PREFIX="$(_get_lan_ipv6_subnet | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_LAN_IPV6="${_LAN_IPV6_PREFIX}2"
    echo "$_PFSENSE_PRIMARY_LAN_IPV6"
}

_get_pfsense_secondary_lan_ipv6() {
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV6" ]; then
        echo "$_PFSENSE_SECONDARY_LAN_IPV6"
        return 0
    fi
    _LAN_IPV6_PREFIX="$(_get_lan_ipv6_subnet | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_LAN_IPV6="${_LAN_IPV6_PREFIX}3"
    echo "$_PFSENSE_SECONDARY_LAN_IPV6"
}

_get_lan_ipv4_dhcp() {
    if [ -n "$_LAN_IPV4_DHCP" ]; then
        echo "$_LAN_IPV4_DHCP"
        return 0
    fi
    _LAN_IPV4_DHCP="$(_get_config_json | jq -r '.network.lan.ipv4.dhcp // ""')"
    if [ "$_LAN_IPV4_DHCP" = "" ] || [ "$_LAN_IPV4_DHCP" = "null" ]; then
        if [ "$(_get_provider)" = "hetzner" ]; then
            _LAN_IPV4_DHCP="false"
        else
            _LAN_IPV4_DHCP="true"
        fi
    fi
    echo "$_LAN_IPV4_DHCP"
}

_get_dns_servers() {
    if [ -n "$_DNS_SERVERS" ]; then
        echo "$_DNS_SERVERS"
        return 0
    fi
    _DNS_SERVERS="$(_get_config_json | jq -r '.network.dns // ""')"
    if [ "$_DNS_SERVERS" = "" ] || [ "$_DNS_SERVERS" = "null" ]; then
        _DNS_SERVERS="1.1.1.1 8.8.8.8"
    fi
    echo "$_DNS_SERVERS"
}

_get_lan_interface() {
    if [ -n "$_LAN_INTERFACE" ]; then
        echo "$_LAN_INTERFACE"
        return 0
    fi
    _LAN_INTERFACE="$(_get_config_json | jq -r '.network.lan.interface // ""')"
    if [ "$_LAN_INTERFACE" = "" ] || [ "$_LAN_INTERFACE" = "null" ]; then
        _LAN_INTERFACE="vtnet1"
    fi
    echo "$_LAN_INTERFACE"
}
