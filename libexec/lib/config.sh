#!/bin/sh

_get_cluster_dir() {
    if [ -n "$_CLUSTER_DIR" ]; then
        echo "$_CLUSTER_DIR"
        return 0
    fi
    if [ -z "$ROCK8S_CONFIG_HOME" ]; then
        _fail "ROCK8S_CONFIG_HOME not set"
    fi
    if [ -z "$ROCK8S_TENANT" ]; then
        _fail "ROCK8S_TENANT not set"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        _fail "ROCK8S_CLUSTER not set"
    fi
    _CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER"
    echo "$_CLUSTER_DIR"
}

_get_config_dir() {
    if [ -n "$_CONFIG_DIR" ]; then
        echo "$_CONFIG_DIR"
        return 0
    fi
    if [ -z "$ROCK8S_CONFIG_HOME" ]; then
        _fail "ROCK8S_CONFIG_HOME not set"
    fi
    if [ -z "$ROCK8S_TENANT" ]; then
        _fail "ROCK8S_TENANT not set"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        _fail "ROCK8S_CLUSTER not set"
    fi
    _CONFIG_DIR="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER"
    echo "$_CONFIG_DIR"
}

_get_config_file() {
    if [ -n "$_CONFIG_FILE" ]; then
        echo "$_CONFIG_FILE"
        return 0
    fi
    _CONFIG_FILE="$(_get_config_dir)/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        _PROVIDERS_DIR="$ROCK8S_LIB_PATH/providers"
        _PROVIDERS_LIST=""
        for _P in "$_PROVIDERS_DIR"/*/ ; do
            if [ -d "$_P" ]; then
                _PROVIDER="$(basename "$_P")"
                _PROVIDERS_LIST="$_PROVIDERS_LIST $_PROVIDER $_PROVIDER"
            fi
        done
        if [ -z "$_PROVIDERS_LIST" ]; then
            _fail "no providers found"
        fi
        _PROVIDER="$(whiptail --title "Select Provider" --notags --menu "Choose your cloud provider" 0 0 0 $_PROVIDERS_LIST 3>&1 1>&2 2>&3)" || _fail "provider selection cancelled"
        mkdir -p "$(dirname "$_CONFIG_FILE")"
        _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
        if [ -f "$_PROVIDER_DIR/config.sh" ] && [ ! -f "$_CONFIG_FILE" ] && [ "$NON_INTERACTIVE" = "0" ]; then
            export CLUSTER="$_CLUSTER"
            { _ERROR="$(sh "$_PROVIDER_DIR/config.sh" "$_CONFIG_FILE")"; _EXIT_CODE="$?"; } || true
            if [ "$_EXIT_CODE" -ne 0 ]; then
                if [ -n "$_ERROR" ]; then
                    _fail "$_ERROR"
                else
                    _fail "provider config script failed"
                fi
            fi
            if [ -f "$_CONFIG_FILE" ]; then
                { _ERROR="$(sh "$ROCK8S_LIB_PATH/providers/addons.sh" "$_CONFIG_FILE")"; _EXIT_CODE="$?"; } || true
                if [ "$_EXIT_CODE" -ne 0 ]; then
                    if [ -n "$_ERROR" ]; then
                        _fail "$_ERROR"
                    else
                        _fail "addons config script failed"
                    fi
                fi
            fi
            if [ ! -f "$_CONFIG_FILE" ]; then
                _fail "provider config script failed to create config file"
            fi
            { echo "provider: $_PROVIDER"; cat "$_CONFIG_FILE"; } > "$_CONFIG_FILE.tmp" && mv "$_CONFIG_FILE.tmp" "$_CONFIG_FILE"
        fi
        if [ ! -f "$_CONFIG_FILE" ]; then
            _fail "cluster configuration file not found at $_CONFIG_FILE"
        fi
    fi
    echo "$_CONFIG_FILE"
}

_get_config_json() {
    if [ -n "$_CONFIG_JSON" ]; then
        echo "$_CONFIG_JSON"
        return 0
    fi
    _CONFIG_FILE="$(_get_config_file)"
    _CONFIG_JSON="$(yaml2json < "$_CONFIG_FILE")"
    if [ -z "$_CONFIG_JSON" ]; then
        _fail "failed to convert cluster configuration file to json"
    fi
    echo "$_CONFIG_JSON"
}

_get_provider() {
    if [ -n "$_PROVIDER" ]; then
        echo "$_PROVIDER"
        return 0
    fi
    _PROVIDER="$(echo "$(_get_config_json)" | jq -r '.provider')"
    if [ -z "$_PROVIDER" ] || [ "$_PROVIDER" = "null" ]; then
        _fail ".provider not found in config.yaml"
    fi
    echo "$_PROVIDER"
}

_get_entrypoint() {
    if [ -n "$_ENTRYPOINT" ]; then
        echo "$_ENTRYPOINT"
        return 0
    fi
    _ENTRYPOINT="$(cat "$(_get_config_json)" | jq -r '.network.entrypoint // ""')"
    if [ -z "$_ENTRYPOINT" ] || [ "$_ENTRYPOINT" = "null" ]; then
        _fail ".network.entrypoint not found in config.yaml"
    fi
    echo "$_ENTRYPOINT"
}



# _get_cluster_addons_dir() {
#     _lookup_cluster_dir
#     echo "$_CLUSTER_DIR/addons"
# }

# _get_cluster_node_type() {
#     _NODE="$1"
#     if echo "$_NODE" | grep -q '^pfsense[0-9]*$'; then
#         echo "pfsense"
#     elif echo "$_NODE" | grep -q '^master[0-9]*$'; then
#         echo "master"
#     elif echo "$_NODE" | grep -q '^worker[0-9]*$'; then
#         echo "worker"
#     else
#         _fail "invalid node type: $_NODE"
#     fi
# }

# _get_cluster_node_index() {
#     _NODE="$1"
#     echo "$_NODE" | sed -E 's/^[a-z]+([0-9]*)$/\1/'
# }

# _get_cluster_node_dir() {
#     _CLUSTER_DIR="$1"
#     _NODE_TYPE="$2"
#     echo "$_CLUSTER_DIR/$_NODE_TYPE"
# }

# # Config getters
# _get_lan_network_subnet() {
#     _subnet="$(echo "$(_get_config_json)" | jq -r '.network.lan.subnet')"
#     if [ -z "$_subnet" ] || [ "$_subnet" = "null" ]; then
#         _fail ".network.lan.subnet not found in config.yaml"
#     fi
#     echo "$_subnet"
# }

# _get_cluster_provider() {
#     _provider="$(echo "$(_get_config_json)" | jq -r '.provider')"
#     if [ -z "$_provider" ] || [ "$_provider" = "null" ]; then
#         _fail ".provider not found in config.yaml"
#     fi
#     echo "$_provider"
# }

# _get_cluster_entrypoint() {
#     _entrypoint="$(echo "$(_get_config_json)" | jq -r '.network.entrypoint')"
#     if [ -z "$_entrypoint" ] || [ "$_entrypoint" = "null" ]; then
#         _fail ".network.entrypoint not found in config.yaml"
#     fi
#     echo "$_entrypoint"
# }

# _get_lan_interface() {
#     echo "$(_get_config_json)" | jq -r '.network.lan.interface // "vtnet1"'
# }

# _get_lan_enable_dhcp() {
#     _dhcp="$(echo "$(_get_config_json)" | jq -r '.network.lan.dhcp // ""')"
#     if [ "$_dhcp" = "" ] || [ "$_dhcp" = "null" ]; then
#         if [ "$(_get_cluster_provider)" = "hetzner" ]; then
#             echo "false"
#         else
#             echo "true"
#         fi
#     else
#         echo "$_dhcp"
#     fi
# }

# _get_dns_servers() {
#     echo "$(_get_config_json)" | jq -r '.network.lan.dns // ["1.1.1.1", "8.8.8.8"] | join(" ")'
# }

# _get_lan_metallb() {
#     _metallb="$(echo "$(_get_config_json)" | jq -r '.network.lan.metallb')"
#     if [ -z "$_metallb" ] || [ "$_metallb" = "null" ]; then
#         _calculate_metallb "$(_get_lan_network_subnet)"
#     else
#         echo "$_metallb"
#     fi
# }

# _get_master_node_count() {
#     _count="$(echo "$(_get_config_json)" | jq -r '.masters | length')"
#     if [ -z "$_count" ] || [ "$_count" = "null" ]; then
#         echo "1"
#     else
#         echo "$_count"
#     fi
# }

# _get_worker_node_count() {
#     _count="$(echo "$(_get_config_json)" | jq -r '.workers[0].count // 1')"
#     if [ -z "$_count" ] || [ "$_count" = "null" ]; then
#         echo "1"
#     else
#         echo "$_count"
#     fi
# }

# _get_node_private_ips() {
#     _NODE_TYPE="$1"
#     jq -r '.node_private_ips.value | to_entries[] | "\(.key) ansible_host=\(.value)"' "$(_get_node_output_json "$_NODE_TYPE")"
# }

# _get_node_ssh_key() {
#     _NODE_TYPE="$1"
#     jq -r '.node_ssh_private_key.value' "$(_get_node_output_json "$_NODE_TYPE")"
# }

# _get_node_master_ipv4() {
#     _NODE_TYPE="$1"
#     jq -r '.node_private_ips.value | .[keys[0]]' "$(_get_node_output_json "$_NODE_TYPE")"
# }

# _get_network_mtu() {
#     echo "$(_get_config_json)" | jq -r '.network.lan.mtu // "1500"'
# }

# _get_network_dualstack() {
#     _dualstack="$(echo "$(_get_config_json)" | jq -r '.network.lan.dualstack')"
#     if [ "$_dualstack" = "false" ]; then
#         echo "false"
#     else
#         echo "true"
#     fi
# }

# _get_supplementary_addresses() {
#     _ENTRYPOINT="$(_get_cluster_entrypoint)"
#     _ENTRYPOINT_IPV4="$(_resolve_hostname "$_ENTRYPOINT")"
#     _MASTER_OUTPUT="$(_get_node_output_json "master")"
#     _MASTER_IPV4S="$(echo "$_MASTER_OUTPUT" | jq -r '.node_private_ips.value | .[] | @text')"
#     _MASTER_EXTERNAL_IPV4S="$(echo "$_MASTER_OUTPUT" | jq -r '.node_ips.value | .[] | @text')"
    
#     _addresses="\"$_ENTRYPOINT\""
#     if [ -n "$_ENTRYPOINT_IPV4" ]; then
#         _addresses="$_addresses,\"$_ENTRYPOINT_IPV4\""
#     fi
#     for _IPV4 in $_MASTER_IPV4S; do
#         _addresses="$_addresses,\"$_IPV4\""
#     done
#     for _IPV4 in $_MASTER_EXTERNAL_IPV4S; do
#         _addresses="$_addresses,\"$_IPV4\""
#     done
#     echo "$_addresses"
# }

# _get_pfsense_primary_hostname() {
#     _primary_hostname="$(echo "$(_get_config_json)" | jq -r '.pfsense[0].hostnames[0] // ""')"
#     if [ -z "$_primary_hostname" ] || [ "$_primary_hostname" = "null" ]; then
#         _primary_hostname="$(echo "$(_get_node_output_json "pfsense")" | jq -r '.node_ips.value | to_entries | .[0].key')"
#     fi
#     echo "$_primary_hostname"
# }

# _get_pfsense_secondary_hostname() {
#     _secondary_hostname="$(echo "$(_get_config_json)" | jq -r '.pfsense[0].hostnames[1] // ""')"
#     if [ -z "$_secondary_hostname" ] || [ "$_secondary_hostname" = "null" ]; then
#         _secondary_hostname="$(echo "$(_get_node_output_json "pfsense")" | jq -r '.node_ips.value | to_entries | .[1].key // ""')"
#     fi
#     echo "$_secondary_hostname"
# }

# _get_pfsense_shared_hostname() {
#     echo "$(_get_config_json)" | jq -r '.pfsense[0].hostnames[2] // ""'
# }

# _get_wan_shared_ipv4() {
#     _shared_hostname="$(_get_pfsense_shared_hostname)"
#     if [ -n "$_shared_hostname" ] && [ "$_shared_hostname" != "null" ]; then
#         _resolve_hostname "$_shared_hostname"
#     fi
# }

# _get_lan_network_ipv4() {
#     _subnet="$1"
#     echo "$_subnet" | cut -d'/' -f1
# }

# _get_lan_network_prefix() {
#     _subnet="$1"
#     echo "$_subnet" | cut -d'/' -f2
# }

# _get_lan_metallb_ingress_ipv4() {
#     _metallb="$1"
#     echo "$_metallb" | cut -d'-' -f1
# }

# _get_lan_ipv6_subnet() {
#     _ipv6_subnet="$(echo "$(_get_config_json)" | jq -r '.network.lan.ipv6_subnet')"
#     if [ -z "$_ipv6_subnet" ] || [ "$_ipv6_subnet" = "null" ]; then
#         _LAN_NETWORK_IPV4="$1"
#         _LAST_NONZERO_OCTET=""
#         _OCTET_COUNT=1
#         for _OCTET in $(echo "$_LAN_NETWORK_IPV4" | tr '.' ' '); do
#             if [ "$_OCTET" != "0" ]; then
#                 _LAST_NONZERO_OCTET="$_OCTET"
#                 _LAST_NONZERO_POSITION="$_OCTET_COUNT"
#             fi
#             _OCTET_COUNT=$((_OCTET_COUNT + 1))
#         done
#         if [ "$_LAST_NONZERO_OCTET" -gt 99 ]; then
#             _PREFIX="$(printf '%02x' "$_LAST_NONZERO_OCTET")"
#         else
#             _PREFIX="$_LAST_NONZERO_OCTET"
#         fi
#         echo "fd${_PREFIX}::/64"
#     else
#         echo "$_ipv6_subnet"
#     fi
# }

# _get_lan_primary_ipv4() {
#     _LAN_NETWORK_IPV4="$1"
#     _calculate_next_ipv4 "$_LAN_NETWORK_IPV4" 2
# }

# _get_lan_secondary_ipv4() {
#     _LAN_NETWORK_IPV4="$1"
#     _calculate_next_ipv4 "$_LAN_NETWORK_IPV4" 3
# }

# _get_lan_master_ipv4() {
#     _LAN_NETWORK_IPV4="$1"
#     _has_secondary="$2"
#     if [ -n "$_has_secondary" ] && [ "$_has_secondary" != "null" ]; then
#         _calculate_next_ipv4 "$_LAN_NETWORK_IPV4" 4
#     else
#         _calculate_next_ipv4 "$_LAN_NETWORK_IPV4" 3
#     fi
# }

# _get_lan_ipv6_prefix() {
#     _LAN_IPV6_SUBNET="$1"
#     echo "$_LAN_IPV6_SUBNET" | cut -d'/' -f1
# }

# _get_lan_primary_ipv6() {
#     _LAN_IPV6_PREFIX="$1"
#     echo "${_LAN_IPV6_PREFIX}2"
# }

# _get_lan_secondary_ipv6() {
#     _LAN_IPV6_PREFIX="$1"
#     echo "${_LAN_IPV6_PREFIX}3"
# }
