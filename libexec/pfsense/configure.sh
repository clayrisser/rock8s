#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense configure - configure pfSense

SYNOPSIS
       rock8s pfsense configure [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--update] [--password <password>] [--ssh-password]

DESCRIPTION
       configure pfsense settings including network interfaces, firewall rules, and system settings

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to configure pfSense for (required)

       --update
              update ansible collections

       --password <password>
              admin password

       --ssh-password
              use password authentication for ssh instead of an ssh key
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _UPDATE=""
    _PASSWORD=""
    _SSH_PASSWORD=0
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
                ;;
            -o|--output|-o=*|--output=*)
                case "$1" in
                    *=*)
                        _FORMAT="${1#*=}"
                        shift
                        ;;
                    *)
                        _FORMAT="$2"
                        shift 2
                        ;;
                esac
                ;;
            -t|--tenant|-t=*|--tenant=*)
                case "$1" in
                    *=*)
                        _TENANT="${1#*=}"
                        shift
                        ;;
                    *)
                        _TENANT="$2"
                        shift 2
                        ;;
                esac
                ;;
            --cluster|--cluster=*)
                case "$1" in
                    *=*)
                        _CLUSTER="${1#*=}"
                        shift
                        ;;
                    *)
                        _CLUSTER="$2"
                        shift 2
                        ;;
                esac
                ;;
            --password|--password=*)
                case "$1" in
                    *=*)
                        _PASSWORD="${1#*=}"
                        shift
                        ;;
                    *)
                        _PASSWORD="$2"
                        shift 2
                        ;;
                esac
                ;;
            --ssh-password)
                _SSH_PASSWORD=1
                shift
                ;;
            --update)
                _UPDATE="1"
                shift
                ;;
            -*)
                _help
                exit 1
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    if [ -z "$_CLUSTER" ]; then
        _fail "cluster name required"
    fi
    _CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$_TENANT/clusters/$_CLUSTER"
    if [ ! -d "$_CLUSTER_DIR" ]; then
        _fail "cluster $_CLUSTER not found"
    fi
    _PFSENSE_DIR="$_CLUSTER_DIR/pfsense"
    if [ "$_SSH_PASSWORD" = "1" ]; then
        command -v sshpass >/dev/null 2>&1 || {
            _fail "sshpass is not installed"
        }
    fi
    _ensure_system
    mkdir -p "$_PFSENSE_DIR"
    _CONFIG_FILE="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT/clusters/$_CLUSTER/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        _fail "cluster configuration file not found at $_CONFIG_FILE"
    fi
    _CONFIG_JSON="$(yaml2json < "$_CONFIG_FILE")"
    _PROVIDER="$(echo "$_CONFIG_JSON" | jq -r '.provider')"
    if [ -n "$_PROVIDER" ] && [ "$_PROVIDER" != "null" ]; then
        _OUTPUT_JSON="$_CLUSTER_DIR/pfsense/output.json"
        if [ ! -f "$_OUTPUT_JSON" ]; then
            _fail "output.json not found for provider $_PROVIDER"
        fi
        _NODE_COUNT="$(jq -r '.node_ips.value | length' "$_OUTPUT_JSON")"
        _PRIMARY_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].hostnames[0] // ""')"
        _SECONDARY_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].hostnames[1] // ""')"
        _SHARED_HOSTNAME="$(echo "$_CONFIG_JSON" | jq -r '.pfsense[0].hostnames[2] // ""')"
        if [ -n "$_SHARED_HOSTNAME" ] && [ "$_SHARED_HOSTNAME" != "null" ]; then
            _SHARED_WAN_IPV4="$(_resolve_hostname "$_SHARED_HOSTNAME")"
        fi
        if [ -z "$_PRIMARY_HOSTNAME" ] || [ "$_PRIMARY_HOSTNAME" = "null" ]; then
            _PRIMARY_HOSTNAME="$(jq -r '.node_ips.value | to_entries | .[0].key' "$_OUTPUT_JSON")"
        fi
        if [ -z "$_SECONDARY_HOSTNAME" ] || [ "$_SECONDARY_HOSTNAME" = "null" ]; then
            _SECONDARY_HOSTNAME="$(jq -r '.node_ips.value | to_entries | .[1].key // ""' "$_OUTPUT_JSON")"
        fi
        _SSH_PRIVATE_KEY="$(jq -r '.node_ssh_private_key.value // ""' "$_OUTPUT_JSON")"
    else
        _NODES_JSON="$(echo "$_CONFIG_JSON" | jq -r '.pfsense.nodes')"
        if [ -z "$_NODES_JSON" ] || [ "$_NODES_JSON" = "null" ]; then
            _fail ".pfsense.nodes not found in config.yaml"
        fi
        _NODE_COUNT="$(echo "$_NODES_JSON" | jq -r 'length')"
        _PRIMARY_HOSTNAME="$(echo "$_NODES_JSON" | jq -r '.[0].hostname // .[0].ip')"
        _SECONDARY_HOSTNAME="$(echo "$_NODES_JSON" | jq -r '.[1].hostname // .[1].ip // ""')"
        _SSH_PRIVATE_KEY="$(echo "$_NODES_JSON" | jq -r '.[0].ssh_private_key // ""')"
    fi
    if [ "$_NODE_COUNT" -lt 1 ]; then
        _fail "at least one pfsense node must be specified"
    fi
    if [ "$_NODE_COUNT" -gt 2 ]; then
        _warn "more than 2 pfsense nodes found but only using first 2 nodes"
    fi
    if [ -z "$_PRIMARY_HOSTNAME" ] || [ "$_PRIMARY_HOSTNAME" = "null" ]; then
        _fail "primary hostname not found"
    fi
    if ([ "$_SSH_PASSWORD" = "1" ] || ([ -n "$_SECONDARY_HOSTNAME" ] && [ "$_SECONDARY_HOSTNAME" != "null" ])) && [ -z "$_PASSWORD" ] && [ "${NON_INTERACTIVE:-0}" = "0" ]; then
        _PASSWORD="$(whiptail --title "Enter admin password" \
            --backtitle "Rock8s Configuration" \
            --passwordbox " " \
            0 0 \
            3>&1 1>&2 2>&3)" || _fail "password required"
    fi
    _NETWORK_SUBNET="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.subnet')"
    if [ -z "$_NETWORK_SUBNET" ] || [ "$_NETWORK_SUBNET" = "null" ]; then
        _fail ".network.lan.subnet not found in config.yaml"
    fi
    _METALLB="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.metallb')"
    if [ -z "$_METALLB" ] || [ "$_METALLB" = "null" ]; then
        _METALLB="$(_calculate_metallb "$_NETWORK_SUBNET")"
    fi
    _INGRESS_IPV4="$(echo "$_METALLB" | cut -d'-' -f1)"
    _INTERFACE="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.interface // "vtnet1"')"
    _DNS_SERVERS="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.dns // ["1.1.1.1", "8.8.8.8"] | join(" ")')"
    _NETWORK_IPV4="$(echo "$_NETWORK_SUBNET" | cut -d'/' -f1)"
    _NETWORK_PREFIX="$(echo "$_NETWORK_SUBNET" | cut -d'/' -f2)"
    _IPV6_SUBNET="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.ipv6_subnet')"
    _ENTRYPOINT="$(echo "$_CONFIG_JSON" | jq -r '.network.entrypoint')"
    if [ -z "$_ENTRYPOINT" ] || [ "$_ENTRYPOINT" = "null" ]; then
        _fail ".network.entrypoint not found in config.yaml"
    fi
    if [ -z "$_IPV6_SUBNET" ] || [ "$_IPV6_SUBNET" = "null" ]; then
        _LAST_NONZERO_OCTET=""
        _OCTET_COUNT=1
        for _OCTET in $(echo "$_NETWORK_IPV4" | tr '.' ' '); do
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
        _IPV6_SUBNET="fd${_PREFIX}::/64"
    fi
    _PRIMARY_IPV4="$(_calculate_next_ipv4 "$_NETWORK_IPV4" 2)"
    _SECONDARY_IPV4="$(_calculate_next_ipv4 "$_NETWORK_IPV4" 3)"
    _IPV6_PREFIX="$(echo "$_IPV6_SUBNET" | cut -d'/' -f1)"
    _PRIMARY_IPV6="${_IPV6_PREFIX}2"
    _SECONDARY_IPV6="${_IPV6_PREFIX}3"
    _ENABLE_DHCP="$(echo "$_CONFIG_JSON" | jq -r '.network.lan.dhcp // ""')"
    if [ "$_ENABLE_DHCP" = "" ] || [ "$_ENABLE_DHCP" = "null" ]; then
        if [ "$_PROVIDER" = "hetzner" ]; then
            _ENABLE_DHCP="false"
        else
            _ENABLE_DHCP="true"
        fi
    fi
    rm -rf "$_PFSENSE_DIR/ansible"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$_PFSENSE_DIR/ansible"
    mkdir -p "$_PFSENSE_DIR/collections"
    ansible-galaxy collection install \
        $([ "$_UPDATE" = "1" ] && echo "--force") \
        -r "$_PFSENSE_DIR/ansible/requirements.yml" \
        -p "$_PFSENSE_DIR/collections"
    mkdir -p "$_PFSENSE_DIR/collections/ansible_collections/pfsensible"
    _DEFAULTS="$(yaml2json < "$_PFSENSE_DIR/ansible/vars.yml")"
    _CONFIG="$(cat <<EOF | yaml2json
pfsense:
  provider: $_PROVIDER
  password: '{{ lookup("env", "PFSENSE_ADMIN_PASSWORD") }}'
  system:
    dns: $_DNS_SERVERS
  network:
    interfaces:
      lan:
        subnet: ${_NETWORK_SUBNET}
        interface: ${_INTERFACE}
        dhcp: ${_ENABLE_DHCP}
        ipv4:
          primary: ${_PRIMARY_IPV4}/${_NETWORK_PREFIX}
          secondary: ${_SECONDARY_IPV4}/${_NETWORK_PREFIX}
        ipv6:
          primary: ${_PRIMARY_IPV6}/64
          secondary: ${_SECONDARY_IPV6}/64
        ips:
          - "$(_calculate_previous_ipv4 "$(_calculate_last_ipv4 "$_NETWORK_SUBNET")" 1)/${_NETWORK_PREFIX}"$([ -n "$_SHARED_WAN_IPV4" ] && echo "
      wan:
        ips:
          - \"$_SHARED_WAN_IPV4\"")
  haproxy:
    rules:
      - "8080 -> check:${_INGRESS_IPV4}:80"
      - "8443 -> check:${_INGRESS_IPV4}:443"
EOF
)"
    echo "$_DEFAULTS" | jq --argjson config "$_CONFIG" '. * $config' | json2yaml > "$_PFSENSE_DIR/vars.yml"
    cat > "$_PFSENSE_DIR/hosts.yml" <<EOF
all:
  vars:
    ansible_user: admin
  hosts:
    pfsense1:
      ansible_host: $_PRIMARY_HOSTNAME
      primary: true
EOF
    if [ -n "$_SECONDARY_HOSTNAME" ] && [ "$_SECONDARY_HOSTNAME" != "null" ]; then
        cat >> "$_PFSENSE_DIR/hosts.yml" <<EOF
    pfsense2:
      ansible_host: $_SECONDARY_HOSTNAME
      primary: false
EOF
    fi
    if [ -n "$_SSH_PRIVATE_KEY" ] && [ "$_SSH_PRIVATE_KEY" != "null" ] && [ "$_SSH_PASSWORD" = "0" ]; then
        export ANSIBLE_PRIVATE_KEY_FILE="$_SSH_PRIVATE_KEY"
    fi
    cd "$_PFSENSE_DIR/ansible"
    ANSIBLE_COLLECTIONS_PATH="$_PFSENSE_DIR/collections:/usr/share/ansible/collections" \
        PFSENSE_ADMIN_PASSWORD="$_PASSWORD" \
        ansible-playbook -v -i "$_PFSENSE_DIR/hosts.yml" \
        -e "@$_PFSENSE_DIR/vars.yml" \
        $([ "$_SSH_PASSWORD" = "1" ] && echo "-e ansible_ssh_pass='$_PASSWORD'") \
        "$_PFSENSE_DIR/ansible/playbooks/configure.yml"
    printf '{"name":"%s"}\n' "$_CLUSTER" | _format_output "$_FORMAT"
}

_main "$@"
