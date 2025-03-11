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

_get_network_mtu() {
    if [ -n "$_NETWORK_MTU" ]; then
        echo "$_NETWORK_MTU"
        return 0
    fi
    _NETWORK_MTU="$(_get_config_json | jq -r '.network.lan.mtu // "1500"')"
    echo "$_NETWORK_MTU"
}

_get_network_dualstack() {
    if [ -n "$_NETWORK_DUALSTACK" ]; then
        echo "$_NETWORK_DUALSTACK"
        return 0
    fi
    _NETWORK_DUALSTACK="$(_get_config_json | jq -r '.network.lan.dualstack')"
    if [ "$_NETWORK_DUALSTACK" = "false" ]; then
        echo "false"
    else
        echo "true"
    fi
}

_get_network_metallb() {
    if [ -n "$_NETWORK_METALLB" ]; then
        echo "$_NETWORK_METALLB"
        return 0
    fi
    _NETWORK_METALLB="$(_get_config_json | jq -r '.network.lan.metallb')"
    if [ -z "$_NETWORK_METALLB" ] || [ "$_NETWORK_METALLB" = "null" ]; then
        _NETWORK_METALLB="$(_calculate_metallb "$(_get_lan_ipv4_subnet)")"
    fi
    echo "$_NETWORK_METALLB"
}

_get_supplementary_addresses() {
    if [ -n "$_SUPPLEMENTARY_ADDRESSES" ]; then
        echo "$_SUPPLEMENTARY_ADDRESSES"
        return 0
    fi
    _ENTRYPOINT="$(_get_entrypoint)"
    _ENTRYPOINT_IPV4="$(_resolve_hostname "$_ENTRYPOINT")"
    _MASTER_OUTPUT="$(_get_cluster_dir)/master/output.json"
    _MASTER_IPV4S="$(jq -r '.node_private_ips.value | .[] | @text' "$_MASTER_OUTPUT")"
    _MASTER_EXTERNAL_IPV4S="$(jq -r '.node_ips.value | .[] | @text' "$_MASTER_OUTPUT")"
    _SUPPLEMENTARY_ADDRESSES="\"$_ENTRYPOINT\""
    if [ -n "$_ENTRYPOINT_IPV4" ]; then
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_ENTRYPOINT_IPV4\""
    fi
    for _IPV4 in $_MASTER_IPV4S; do
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_IPV4\""
    done
    for _IPV4 in $_MASTER_EXTERNAL_IPV4S; do
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_IPV4\""
    done
    echo "$_SUPPLEMENTARY_ADDRESSES"
}
