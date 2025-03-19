#!/bin/sh

set -e

get_pfsense_output_json_file() {
    if [ -n "$_PFSENSE_OUTPUT_JSON_FILE" ]; then
        echo "$_PFSENSE_OUTPUT_JSON_FILE"
        return
    fi
    _PFSENSE_OUTPUT_JSON_FILE="$(get_cluster_dir)/pfsense/output.json"
    echo "$_PFSENSE_OUTPUT_JSON_FILE"
}

get_pfsense_output_json() {
    if [ -n "$_PFSENSE_OUTPUT_JSON" ]; then
        echo "$_PFSENSE_OUTPUT_JSON"
        return
    fi
    _PFSENSE_OUTPUT_JSON_FILE="$(get_pfsense_output_json_file)"
    if [ -f "$_PFSENSE_OUTPUT_JSON_FILE" ]; then
        _PFSENSE_OUTPUT_JSON="$(cat "$_PFSENSE_OUTPUT_JSON_FILE")"
    else
        _PFSENSE_OUTPUT_JSON='{}'
    fi
    echo "$_PFSENSE_OUTPUT_JSON"
}

get_pfsense_ssh_private_key() {
    if [ -n "$_PFSENSE_SSH_PRIVATE_KEY" ]; then
        echo "$_PFSENSE_SSH_PRIVATE_KEY"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    if [ "$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].type // ""')" = "" ]; then
        _PFSENSE_SSH_PRIVATE_KEY="$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].ssh_private_key // ""')"
    fi
    if [ -z "$_PFSENSE_SSH_PRIVATE_KEY" ]; then
        _PFSENSE_SSH_PRIVATE_KEY="$(get_pfsense_output_json | jq -r '.node_ssh_private_key.value // ""')"
    fi
    echo "$_PFSENSE_SSH_PRIVATE_KEY"
}

get_pfsense_primary_hostname() {
    if [ -n "$_PFSENSE_PRIMARY_HOSTNAME" ]; then
        echo "$_PFSENSE_PRIMARY_HOSTNAME"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PFSENSE_PRIMARY_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].hostnames[0] // ""')"
    if [ -z "$_PFSENSE_PRIMARY_HOSTNAME" ]; then
        fail ".pfsense[0].hostnames[0] not found in config.yaml"
    fi
    echo "$_PFSENSE_PRIMARY_HOSTNAME"
}

get_pfsense_secondary_hostname() {
    if [ -n "$_PFSENSE_SECONDARY_HOSTNAME" ]; then
        echo "$_PFSENSE_SECONDARY_HOSTNAME"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PFSENSE_SECONDARY_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].hostnames[1] // ""')"
    echo "$_PFSENSE_SECONDARY_HOSTNAME"
}

get_pfsense_shared_hostname() {
    if [ -n "$_PFSENSE_SHARED_HOSTNAME" ]; then
        echo "$_PFSENSE_SHARED_HOSTNAME"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PFSENSE_SHARED_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].hostnames[2] // ""')"
    echo "$_PFSENSE_SHARED_HOSTNAME"
}

get_sync_ipv4_subnet() {
    if [ -n "$_SYNC_IPV4_SUBNET" ]; then
        echo "$_SYNC_IPV4_SUBNET"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _SYNC_IPV4_SUBNET="$(echo "$_CONFIG_JSON" | jq -r '.network.sync.ipv4.subnet // ""')"
    echo "$_SYNC_IPV4_SUBNET"
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

get_lan_ipv6_subnet() {
    if [ -n "$_LAN_IPV6_SUBNET" ]; then
        echo "$_LAN_IPV6_SUBNET"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _LAN_IPV6_SUBNET="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.ipv6.subnet // ""')"
    if [ -z "$_LAN_IPV6_SUBNET" ]; then
        _LAN_IPV4_NETWORK="$(get_lan_ipv4_subnet | cut -d'/' -f1)"
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

get_pfsense_shared_wan_ipv4() {
    if [ -n "$_PFSENSE_SHARED_WAN_IPV4" ]; then
        echo "$_PFSENSE_SHARED_WAN_IPV4"
        return
    fi
    _PFSENSE_SHARED_WAN_IPV4="$(_resolve_hostname "$(get_pfsense_shared_hostname)")"
    echo "$_PFSENSE_SHARED_WAN_IPV4"
}

get_pfsense_primary_wan_ipv4() {
    if [ -n "$_PFSENSE_PRIMARY_WAN_IPV4" ]; then
        echo "$_PFSENSE_PRIMARY_WAN_IPV4"
        return
    fi
    _PFSENSE_PRIMARY_WAN_IPV4="$(_resolve_hostname "$(get_pfsense_primary_hostname)")"
    echo "$_PFSENSE_PRIMARY_WAN_IPV4"
}

get_pfsense_secondary_wan_ipv4() {
    if [ -n "$_PFSENSE_SECONDARY_WAN_IPV4" ]; then
        echo "$_PFSENSE_SECONDARY_WAN_IPV4"
        return
    fi
    _PFSENSE_SECONDARY_WAN_IPV4="$(_resolve_hostname "$(get_pfsense_secondary_hostname)")"
    echo "$_PFSENSE_SECONDARY_WAN_IPV4"
}

get_pfsense_primary_lan_ipv4() {
    if [ -n "$_PFSENSE_PRIMARY_LAN_IPV4" ]; then
        echo "$_PFSENSE_PRIMARY_LAN_IPV4"
        return
    fi
    _LAN_IPV4_NETWORK="$(get_lan_ipv4_subnet | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_LAN_IPV4="$(calculate_next_ipv4 "$_LAN_IPV4_NETWORK" 2)"
    echo "$_PFSENSE_PRIMARY_LAN_IPV4"
}

get_pfsense_secondary_lan_ipv4() {
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV4" ]; then
        echo "$_PFSENSE_SECONDARY_LAN_IPV4"
        return
    fi
    _LAN_IPV4_NETWORK="$(get_lan_ipv4_subnet | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_LAN_IPV4="$(calculate_next_ipv4 "$_LAN_IPV4_NETWORK" 3)"
    echo "$_PFSENSE_SECONDARY_LAN_IPV4"
}

get_pfsense_primary_sync_ipv4() {
    if [ -n "$_PFSENSE_PRIMARY_SYNC_IPV4" ]; then
        echo "$_PFSENSE_PRIMARY_SYNC_IPV4"
        return
    fi
    _SYNC_IPV4_SUBNET="$(get_sync_ipv4_subnet)"
    if [ -z "$_SYNC_IPV4_SUBNET" ]; then
        return
    fi
    _SYNC_IPV4_NETWORK="$(echo "$_SYNC_IPV4_SUBNET" | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_SYNC_IPV4="$(calculate_next_ipv4 "$_SYNC_IPV4_NETWORK" 2)"
    echo "$_PFSENSE_PRIMARY_SYNC_IPV4"
}

get_pfsense_secondary_sync_ipv4() {
    if [ -n "$_PFSENSE_SECONDARY_SYNC_IPV4" ]; then
        echo "$_PFSENSE_SECONDARY_SYNC_IPV4"
        return
    fi
    _SYNC_IPV4_SUBNET="$(get_sync_ipv4_subnet)"
    if [ -z "$_SYNC_IPV4_SUBNET" ]; then
        return
    fi
    _SYNC_IPV4_NETWORK="$(echo "$_SYNC_IPV4_SUBNET" | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_SYNC_IPV4="$(calculate_next_ipv4 "$_SYNC_IPV4_NETWORK" 3)"
    echo "$_PFSENSE_SECONDARY_SYNC_IPV4"
}

get_pfsense_shared_lan_ipv4() {
    if [ -n "$_PFSENSE_SHARED_LAN_IPV4" ]; then
        echo "$_PFSENSE_SHARED_LAN_IPV4"
        return
    fi
    _PFSENSE_SHARED_LAN_IPV4="$(calculate_last_ipv4 "$(get_lan_ipv4_subnet)")"
    echo "$_PFSENSE_SHARED_LAN_IPV4"
}

get_pfsense_primary_lan_ipv6() {
    if [ -n "$_PFSENSE_PRIMARY_LAN_IPV6" ]; then
        echo "$_PFSENSE_PRIMARY_LAN_IPV6"
        return
    fi
    _LAN_IPV6_PREFIX="$(get_lan_ipv6_subnet | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_LAN_IPV6="${_LAN_IPV6_PREFIX}2"
    echo "$_PFSENSE_PRIMARY_LAN_IPV6"
}

get_pfsense_secondary_lan_ipv6() {
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV6" ]; then
        echo "$_PFSENSE_SECONDARY_LAN_IPV6"
        return
    fi
    _LAN_IPV6_PREFIX="$(get_lan_ipv6_subnet | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_LAN_IPV6="${_LAN_IPV6_PREFIX}3"
    echo "$_PFSENSE_SECONDARY_LAN_IPV6"
}

get_lan_ipv4_dhcp() {
    if [ -n "$_LAN_IPV4_DHCP" ]; then
        echo "$_LAN_IPV4_DHCP"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _LAN_IPV4_DHCP="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.ipv4.dhcp // ""')"
    if [ "$_LAN_IPV4_DHCP" = "" ]; then
        if [ "$(get_external_network)" = "1" ]; then
            _LAN_IPV4_DHCP="false"
        else
            _LAN_IPV4_DHCP="true"
        fi
    fi
    echo "$_LAN_IPV4_DHCP"
}

get_dns_servers() {
    if [ -n "$_DNS_SERVERS" ]; then
        echo "$_DNS_SERVERS"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _DNS_SERVERS="$(echo "$_CONFIG_JSON" | jq -r '.network.dns // ""')"
    if [ "$_DNS_SERVERS" = "" ]; then
        _DNS_SERVERS="1.1.1.1 8.8.8.8"
    fi
    echo "$_DNS_SERVERS"
}

get_lan_interface() {
    if [ -n "$_LAN_INTERFACE" ]; then
        echo "$_LAN_INTERFACE"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _LAN_INTERFACE="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.interface // ""')"
    if [ "$_LAN_INTERFACE" = "" ]; then
        _LAN_INTERFACE="vtnet1"
    fi
    echo "$_LAN_INTERFACE"
}

get_sync_interface() {
    if [ -n "$_SYNC_INTERFACE" ]; then
        echo "$_SYNC_INTERFACE"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _SYNC_INTERFACE="$(echo "$_CONFIG_JSON" | jq -r '.network.sync.interface // ""')"
    if [ "$_SYNC_INTERFACE" = "" ]; then
        _SYNC_INTERFACE="vtnet2"
    fi
    echo "$_SYNC_INTERFACE"
}

get_haproxy_backend() {
    _HAPROXY_PORT="$1"
    shift
    _HAPROXY_BACKEND=""
    for _IP in "$@"; do
        if [ -n "$_HAPROXY_BACKEND" ]; then
            _HAPROXY_BACKEND="${_HAPROXY_BACKEND},check:${_IP}:${_HAPROXY_PORT}"
        else
            _HAPROXY_BACKEND="check:${_IP}:${_HAPROXY_PORT}"
        fi
    done
    echo "$_HAPROXY_BACKEND"
}

get_pfsense_althostnames() {
    if [ -n "$_PFSENSE_ALTHOSTNAMES" ]; then
        echo "$_PFSENSE_ALTHOSTNAMES"
        return
    fi
    for _HOSTNAME in \
        "$(get_pfsense_primary_hostname)" \
        "$(get_pfsense_primary_lan_ipv4)" \
        "$(get_pfsense_primary_lan_ipv6)" \
        "$(get_pfsense_primary_wan_ipv4)" \
        "$(get_pfsense_secondary_hostname)" \
        "$(get_pfsense_secondary_lan_ipv4)" \
        "$(get_pfsense_secondary_lan_ipv6)" \
        "$(get_pfsense_secondary_wan_ipv4)" \
        "$(get_pfsense_shared_hostname)" \
        "$(get_pfsense_shared_lan_ipv4)" \
        "$(get_pfsense_shared_wan_ipv4)"; do
        if [ -n "$_HOSTNAME" ]; then
            if [ -n "$_PFSENSE_ALTHOSTNAMES" ]; then
                _PFSENSE_ALTHOSTNAMES="$_PFSENSE_ALTHOSTNAMES $_HOSTNAME"
            else
                _PFSENSE_ALTHOSTNAMES="$_HOSTNAME"
            fi
        fi
    done
    echo "$_PFSENSE_ALTHOSTNAMES"
}

get_pfsense_private_ipv4s() {
    if [ -n "$_PFSENSE_PRIVATE_IPV4S" ]; then
        echo "$_PFSENSE_PRIVATE_IPV4S"
        return
    fi
    _PFSENSE_PRIVATE_IPV4S="$(get_pfsense_output_json | jq -r '.node_private_ipv4s.value | to_entries[]? | .value // empty')"
    echo "$_PFSENSE_PRIVATE_IPV4S"
}

get_pfsense_public_ipv4s() {
    if [ -n "$_PFSENSE_PUBLIC_IPV4S" ]; then
        echo "$_PFSENSE_PUBLIC_IPV4S"
        return
    fi
    _PFSENSE_PRIMARY_WAN_IPV4="$(get_pfsense_primary_wan_ipv4)"
    _PFSENSE_SECONDARY_WAN_IPV4="$(get_pfsense_secondary_wan_ipv4)"
    if [ -n "$_PFSENSE_SECONDARY_WAN_IPV4" ]; then
        _PFSENSE_PUBLIC_IPV4S="$_PFSENSE_PRIMARY_WAN_IPV4 $_PFSENSE_SECONDARY_WAN_IPV4"
    else
        _PFSENSE_PUBLIC_IPV4S="$_PFSENSE_PRIMARY_WAN_IPV4"
    fi
    echo "$_PFSENSE_PUBLIC_IPV4S"
}
