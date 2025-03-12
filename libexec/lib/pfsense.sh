#!/bin/sh

_get_pfsense_output_json_file() {
    if [ -n "$_PFSENSE_OUTPUT_JSON_FILE" ]; then
        echo "$_PFSENSE_OUTPUT_JSON_FILE"
        return
    fi
    _PFSENSE_OUTPUT_JSON_FILE="$(_get_cluster_dir)/pfsense/output.json"
    echo "$_PFSENSE_OUTPUT_JSON_FILE"
}

_get_pfsense_output_json() {
    if [ -n "$_PFSENSE_OUTPUT_JSON" ]; then
        echo "$_PFSENSE_OUTPUT_JSON"
        return
    fi
    _PFSENSE_OUTPUT_JSON_FILE="$(_get_pfsense_output_json_file)"
    if [ -f "$_PFSENSE_OUTPUT_JSON_FILE" ]; then
        _PFSENSE_OUTPUT_JSON="$(cat "$_PFSENSE_OUTPUT_JSON_FILE")"
    else
        _fail "pfsense output.json not found"
    fi
    echo "$_PFSENSE_OUTPUT_JSON"
}

_get_pfsense_ansible_private_hosts() {
    if [ -n "$_PFSENSE_ANSIBLE_PRIVATE_HOSTS" ]; then
        echo "$_PFSENSE_ANSIBLE_PRIVATE_HOSTS"
        return
    fi
    _PFSENSE_ANSIBLE_PRIVATE_HOSTS="$(_get_pfsense_output_json | jq -r '.node_private_ips.value | to_entries[] | "\(.key) ansible_host=\(.value)"')"
    echo "$_PFSENSE_ANSIBLE_PRIVATE_HOSTS"
}

_get_pfsense_ssh_private_key() {
    if [ -n "$_PFSENSE_SSH_PRIVATE_KEY" ]; then
        echo "$_PFSENSE_SSH_PRIVATE_KEY"
        return
    fi
    _PFSENSE_SSH_PRIVATE_KEY="$(_get_pfsense_output_json | jq -r '.node_ssh_private_key.value // ""')"
    echo "$_PFSENSE_SSH_PRIVATE_KEY"
}

_get_pfsense_node_count() {
    if [ -n "$_PFSENSE_NODE_COUNT" ]; then
        echo "$_PFSENSE_NODE_COUNT"
        return
    fi
    _PFSENSE_NODE_COUNT="$(_get_pfsense_output_json | jq -r '.node_private_ips.value | length')"
    echo "$_PFSENSE_NODE_COUNT"
}

_get_pfsense_private_ipv4s() {
    if [ -n "$_PFSENSE_PRIVATE_IPV4S" ]; then
        echo "$_PFSENSE_PRIVATE_IPV4S"
        return
    fi
    _PFSENSE_PRIVATE_IPV4S="$(_get_pfsense_output_json | jq -r '.node_private_ips.value | .[] | @text')"
    echo "$_PFSENSE_PRIVATE_IPV4S"
}

_get_pfsense_public_ipv4s() {
    if [ -n "$_PFSENSE_PUBLIC_IPV4S" ]; then
        echo "$_PFSENSE_PUBLIC_IPV4S"
        return
    fi
    _PFSENSE_PUBLIC_IPV4S="$(_get_pfsense_output_json | jq -r '.node_public_ips.value | .[] | @text')"
    echo "$_PFSENSE_PUBLIC_IPV4S"
}

_get_pfsense_primary_hostname() {
    if [ -n "$_PFSENSE_PRIMARY_HOSTNAME" ]; then
        echo "$_PFSENSE_PRIMARY_HOSTNAME"
        return
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
        return
    fi
    _PFSENSE_SECONDARY_HOSTNAME="$(_get_config_json | jq -r '.pfsense[0].hostnames[1] // ""')"
    echo "$_PFSENSE_SECONDARY_HOSTNAME"
}

_get_pfsense_shared_hostname() {
    if [ -n "$_PFSENSE_SHARED_HOSTNAME" ]; then
        echo "$_PFSENSE_SHARED_HOSTNAME"
        return
    fi
    _PFSENSE_SHARED_HOSTNAME="$(_get_config_json | jq -r '.pfsense[0].hostnames[2] // ""')"
    echo "$_PFSENSE_SHARED_HOSTNAME"
}

_get_pfsense_shared_wan_ipv4() {
    if [ -n "$_PFSENSE_SHARED_WAN_IPV4" ]; then
        echo "$_PFSENSE_SHARED_WAN_IPV4"
        return
    fi
    _PFSENSE_SHARED_WAN_IPV4="$(_resolve_hostname "$(_get_pfsense_shared_hostname)")"
    echo "$_PFSENSE_SHARED_WAN_IPV4"
}

_get_pfsense_primary_lan_ipv4() {
    if [ -n "$_PFSENSE_PRIMARY_LAN_IPV4" ]; then
        echo "$_PFSENSE_PRIMARY_LAN_IPV4"
        return
    fi
    _LAN_IPV4_NETWORK="$(_get_lan_ipv4_subnet | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_LAN_IPV4="$(_calculate_next_ipv4 "$_LAN_IPV4_NETWORK" 2)"
    echo "$_PFSENSE_PRIMARY_LAN_IPV4"
}

_get_pfsense_secondary_lan_ipv4() {
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV4" ]; then
        echo "$_PFSENSE_SECONDARY_LAN_IPV4"
        return
    fi
    _LAN_IPV4_NETWORK="$(_get_lan_ipv4_subnet | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_LAN_IPV4="$(_calculate_next_ipv4 "$_LAN_IPV4_NETWORK" 3)"
    echo "$_PFSENSE_SECONDARY_LAN_IPV4"
}

_get_pfsense_shared_lan_ipv4() {
    if [ -n "$_PFSENSE_SHARED_LAN_IPV4" ]; then
        echo "$_PFSENSE_SHARED_LAN_IPV4"
        return
    fi
    _PFSENSE_SHARED_LAN_IPV4="$(_calculate_last_ipv4 "$(_get_lan_ipv4_subnet)")"
    echo "$_PFSENSE_SHARED_LAN_IPV4"
}

_get_pfsense_primary_lan_ipv6() {
    if [ -n "$_PFSENSE_PRIMARY_LAN_IPV6" ]; then
        echo "$_PFSENSE_PRIMARY_LAN_IPV6"
        return
    fi
    _LAN_IPV6_PREFIX="$(_get_lan_ipv6_subnet | cut -d'/' -f1)"
    _PFSENSE_PRIMARY_LAN_IPV6="${_LAN_IPV6_PREFIX}2"
    echo "$_PFSENSE_PRIMARY_LAN_IPV6"
}

_get_pfsense_secondary_lan_ipv6() {
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV6" ]; then
        echo "$_PFSENSE_SECONDARY_LAN_IPV6"
        return
    fi
    _LAN_IPV6_PREFIX="$(_get_lan_ipv6_subnet | cut -d'/' -f1)"
    _PFSENSE_SECONDARY_LAN_IPV6="${_LAN_IPV6_PREFIX}3"
    echo "$_PFSENSE_SECONDARY_LAN_IPV6"
}

_get_lan_ipv4_subnet() {
    if [ -n "$_LAN_IPV4_SUBNET" ]; then
        echo "$_LAN_IPV4_SUBNET"
        return
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
        return
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

_get_lan_ipv4_dhcp() {
    if [ -n "$_LAN_IPV4_DHCP" ]; then
        echo "$_LAN_IPV4_DHCP"
        return
    fi
    _LAN_IPV4_DHCP="$(_get_config_json | jq -r '.network.lan.ipv4.dhcp // ""')"
    if [ "$_LAN_IPV4_DHCP" = "" ] || [ "$_LAN_IPV4_DHCP" = "null" ]; then
        if [ "$(_get_external_network)" = "1" ]; then
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
        return
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
        return
    fi
    _LAN_INTERFACE="$(_get_config_json | jq -r '.network.lan.interface // ""')"
    if [ "$_LAN_INTERFACE" = "" ] || [ "$_LAN_INTERFACE" = "null" ]; then
        _LAN_INTERFACE="vtnet1"
    fi
    echo "$_LAN_INTERFACE"
}

_get_haproxy_backend() {
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
