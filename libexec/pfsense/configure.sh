#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense configure - configure pfSense

SYNOPSIS
       rock8s pfsense configure [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--force]

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

       --force
              force reinstall of ansible collections
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER=""
    _TENANT="$ROCK8S_TENANT"
    _FORCE=""
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
            --force)
                _FORCE="1"
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
    _ensure_system
    _CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$_TENANT/clusters/$_CLUSTER"
    if [ ! -d "$_CLUSTER_DIR" ]; then
        _fail "cluster $_CLUSTER not found"
    fi
    _PFSENSE_DIR="$_CLUSTER_DIR/pfsense"
    mkdir -p "$_PFSENSE_DIR"
    _CONFIG_FILE="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT/clusters/$_CLUSTER/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        _fail "cluster configuration file not found at $_CONFIG_FILE"
    fi
    _PROVIDER="$(_yaml2json < "$_CONFIG_FILE" | jq -r '.provider')"
    if [ -n "$_PROVIDER" ] && [ "$_PROVIDER" != "null" ]; then
        _OUTPUT_JSON="$_CLUSTER_DIR/pfsense/output.json"
        if [ ! -f "$_OUTPUT_JSON" ]; then
            _fail "output.json not found for provider $_PROVIDER"
        fi
        _NODE_COUNT="$(jq -r '.node_ips.value | length' "$_OUTPUT_JSON")"
        _PRIMARY_HOSTNAME="$(_yaml2json < "$_CONFIG_FILE" | jq -r '.pfsense[0].hostnames[0] // ""')"
        _SECONDARY_HOSTNAME="$(_yaml2json < "$_CONFIG_FILE" | jq -r '.pfsense[0].hostnames[1] // ""')"
        if [ -z "$_PRIMARY_HOSTNAME" ] || [ "$_PRIMARY_HOSTNAME" = "null" ]; then
            _PRIMARY_HOSTNAME="$(jq -r '.node_ips.value | to_entries | .[0].key' "$_OUTPUT_JSON")"
        fi
        if [ -z "$_SECONDARY_HOSTNAME" ] || [ "$_SECONDARY_HOSTNAME" = "null" ]; then
            _SECONDARY_HOSTNAME="$(jq -r '.node_ips.value | to_entries | .[1].key // ""' "$_OUTPUT_JSON")"
        fi
        _SSH_PRIVATE_KEY="$(jq -r '.node_ssh_private_key.value // ""' "$_OUTPUT_JSON")"
    else
        _NODES_JSON="$(_yaml2json < "$_CONFIG_FILE" | jq -r '.pfsense.nodes')"
        if [ -z "$_NODES_JSON" ] || [ "$_NODES_JSON" = "null" ]; then
            _fail "pfsense.nodes not specified in config.yaml"
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
    rm -rf "$_PFSENSE_DIR/ansible"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$_PFSENSE_DIR/ansible"
    mkdir -p "$_PFSENSE_DIR/collections"
    ansible-galaxy collection install \
        $([ "$_FORCE" = "1" ] && echo "--force") \
        -r "$_PFSENSE_DIR/ansible/requirements.yml" \
        -p "$_PFSENSE_DIR/collections"
    cat > "$_PFSENSE_DIR/hosts.yml" <<EOF
all:
  children:
    primary:
      hosts:
        pfsense1:
          ansible_host: $_PRIMARY_HOSTNAME
          ansible_user: root
      vars:
        primary: true
EOF
    if [ -n "$_SECONDARY_HOSTNAME" ] && [ "$_SECONDARY_HOSTNAME" != "null" ]; then
        cat >> "$_PFSENSE_DIR/hosts.yml" <<EOF
    secondary:
      hosts:
        pfsense2:
          ansible_host: $_SECONDARY_HOSTNAME
          ansible_user: root
      vars:
        primary: false
EOF
    fi
    if [ -n "$_SSH_PRIVATE_KEY" ] && [ "$_SSH_PRIVATE_KEY" != "null" ]; then
        export ANSIBLE_PRIVATE_KEY_FILE="$_SSH_PRIVATE_KEY"
    fi
    cd "$_PFSENSE_DIR/ansible"
    ANSIBLE_COLLECTIONS_PATH="$_PFSENSE_DIR/collections:/usr/share/ansible/collections" \
        ansible-playbook -v -i "$_PFSENSE_DIR/hosts.yml" \
        "$_PFSENSE_DIR/ansible/playbooks/configure.yml"
    printf '{"name":"%s"}\n' "$_CLUSTER" | _format_output "$_FORMAT"
}

_main "$@"
