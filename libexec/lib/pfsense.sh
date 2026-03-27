#!/bin/sh

set -e

get_pfsense_ssh_private_key() {
    if [ -n "$_PFSENSE_SSH_PRIVATE_KEY" ]; then
        echo "$_PFSENSE_SSH_PRIVATE_KEY"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PFSENSE_SSH_PRIVATE_KEY="$(echo "$_CONFIG_JSON" | jq -r '.pfsense.ssh_private_key // ""')"
    if [ -z "$_PFSENSE_SSH_PRIVATE_KEY" ] || [ ! -f "$_PFSENSE_SSH_PRIVATE_KEY" ]; then
        pfsense_dir="$(get_pfsense_dir)"
        if [ -f "$pfsense_dir/id_rsa" ]; then
            _PFSENSE_SSH_PRIVATE_KEY="$pfsense_dir/id_rsa"
        fi
    fi
    echo "$_PFSENSE_SSH_PRIVATE_KEY"
}

is_pfsense_provisioned() {
    _CONFIG_JSON="$(get_config_json)"
    pfsense_type="$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].type // ""')"
    if [ -n "$pfsense_type" ] && [ "$pfsense_type" != "null" ]; then
        return 0
    fi
    return 1
}

get_pfsense_primary_hostname() {
    if [ -n "$_PFSENSE_PRIMARY_HOSTNAME" ]; then
        echo "$_PFSENSE_PRIMARY_HOSTNAME"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PFSENSE_PRIMARY_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense.hostname // ""')"
    if [ -z "$_PFSENSE_PRIMARY_HOSTNAME" ]; then
        fail ".pfsense.hostname not found in config.yaml"
    fi
    echo "$_PFSENSE_PRIMARY_HOSTNAME"
}

get_pfsense_secondary_hostname() {
    if [ -n "$_PFSENSE_SECONDARY_HOSTNAME" ]; then
        echo "$_PFSENSE_SECONDARY_HOSTNAME"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PFSENSE_SECONDARY_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense.secondary_hostname // ""')"
    echo "$_PFSENSE_SECONDARY_HOSTNAME"
}

get_pfsense_shared_hostname() {
    if [ -n "$_PFSENSE_SHARED_HOSTNAME" ]; then
        echo "$_PFSENSE_SHARED_HOSTNAME"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PFSENSE_SHARED_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense.shared_hostname // ""')"
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
        lan_ipv4_network="$(get_lan_ipv4_subnet | cut -d'/' -f1)"
        last_nonzero_octet=""
        octet_count=1
        for octet in $(echo "$lan_ipv4_network" | tr '.' ' '); do
            if [ "$octet" != "0" ]; then
                last_nonzero_octet="$octet"
                last_nonzero_position="$octet_count"
            fi
            octet_count=$((octet_count + 1))
        done
        if [ "$last_nonzero_octet" -gt 99 ]; then
            prefix="$(printf '%02x' "$last_nonzero_octet")"
        else
            prefix="$last_nonzero_octet"
        fi
        _LAN_IPV6_SUBNET="fd${prefix}::/64"
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
    lan_ipv4_network="$(get_lan_ipv4_subnet | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_LAN_IPV4="$(calculate_next_ipv4 "$lan_ipv4_network" 2)"
    echo "$_PFSENSE_PRIMARY_LAN_IPV4"
}

get_pfsense_secondary_lan_ipv4() {
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV4" ]; then
        echo "$_PFSENSE_SECONDARY_LAN_IPV4"
        return
    fi
    lan_ipv4_network="$(get_lan_ipv4_subnet | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_LAN_IPV4="$(calculate_next_ipv4 "$lan_ipv4_network" 3)"
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
    sync_ipv4_network="$(echo "$_SYNC_IPV4_SUBNET" | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_SYNC_IPV4="$(calculate_next_ipv4 "$sync_ipv4_network" 2)"
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
    sync_ipv4_network="$(echo "$_SYNC_IPV4_SUBNET" | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_SYNC_IPV4="$(calculate_next_ipv4 "$sync_ipv4_network" 3)"
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
    lan_ipv6_prefix="$(get_lan_ipv6_subnet | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_LAN_IPV6="${lan_ipv6_prefix}2"
    echo "$_PFSENSE_PRIMARY_LAN_IPV6"
}

get_pfsense_secondary_lan_ipv6() {
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV6" ]; then
        echo "$_PFSENSE_SECONDARY_LAN_IPV6"
        return
    fi
    lan_ipv6_prefix="$(get_lan_ipv6_subnet | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_LAN_IPV6="${lan_ipv6_prefix}3"
    echo "$_PFSENSE_SECONDARY_LAN_IPV6"
}

get_lan_ipv4_dhcp() {
    if [ -n "$_LAN_IPV4_DHCP" ]; then
        echo "$_LAN_IPV4_DHCP"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _LAN_IPV4_DHCP="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.ipv4.dhcp // "false"')"
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
    haproxy_port="$1"
    shift
    haproxy_backend=""
    for ip in "$@"; do
        if [ -n "$haproxy_backend" ]; then
            haproxy_backend="${haproxy_backend},check:${ip}:${haproxy_port}"
        else
            haproxy_backend="check:${ip}:${haproxy_port}"
        fi
    done
    echo "$haproxy_backend"
}

get_pfsense_althostnames() {
    if [ -n "$_PFSENSE_ALTHOSTNAMES" ]; then
        echo "$_PFSENSE_ALTHOSTNAMES"
        return
    fi
    for hostname in \
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
        if [ -n "$hostname" ]; then
            if [ -n "$_PFSENSE_ALTHOSTNAMES" ]; then
                _PFSENSE_ALTHOSTNAMES="$_PFSENSE_ALTHOSTNAMES $hostname"
            else
                _PFSENSE_ALTHOSTNAMES="$hostname"
            fi
        fi
    done
    echo "$_PFSENSE_ALTHOSTNAMES"
}

