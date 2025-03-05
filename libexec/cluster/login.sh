#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_TEMP_FILES=""
_cleanup() {
    if [ -n "$_TEMP_FILES" ]; then
        for _FILE in $_TEMP_FILES; do
            [ -f "$_FILE" ] && rm -rf "$_FILE" || true
        done
    fi
}

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster login - login to kubernetes cluster

SYNOPSIS
       rock8s cluster login [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>]

DESCRIPTION
       login to kubernetes cluster and configure kubectl

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to login to (required)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER=""
    _TENANT="$ROCK8S_TENANT"
    trap _cleanup EXIT INT TERM
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
    _CONFIG_FILE="$ROCK8S_CONFIG_HOME/tenants/$_TENANT/clusters/$_CLUSTER/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        _fail "cluster configuration file not found at $_CONFIG_FILE"
    fi
    _MASTER_OUTPUT="$_CLUSTER_DIR/master/output.json"
    if [ ! -f "$_MASTER_OUTPUT" ]; then
        _fail "master output.json not found"
    fi
    _KUBESPRAY_DIR="$_CLUSTER_DIR/kubespray"
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        _fail "kubespray directory not found at $_KUBESPRAY_DIR"
    fi
    _INVENTORY_FILE="$_CLUSTER_DIR/inventory/inventory.ini"
    if [ ! -f "$_INVENTORY_FILE" ]; then
        _fail "inventory file not found at $_INVENTORY_FILE"
    fi
    _MASTER_IP="$(grep -A1 '\[kube_control_plane\]' "$_INVENTORY_FILE" | tail -n1 | grep -o 'ansible_host=[^ ]*' | cut -d'=' -f2)"
    if [ -z "$_MASTER_IP" ]; then
        _fail "could not find control plane node ip in inventory file"
    fi
    _SSH_KEY_FILE="$(jq -r '.node_ssh_private_key.value' "$_MASTER_OUTPUT")"
    if [ -z "$_SSH_KEY_FILE" ] || [ "$_SSH_KEY_FILE" = "null" ]; then
        _fail "ssh private key path not found in master output.json"
    fi
    if [ ! -f "$_SSH_KEY_FILE" ]; then
        _fail "ssh private key file not found at $_SSH_KEY_FILE"
    fi
    _ENTRYPOINT="$(yaml2json < "$_CONFIG_FILE" | jq -r '.network.entrypoint')"
    if [ -z "$_ENTRYPOINT" ] || [ "$_ENTRYPOINT" = "null" ]; then
        _fail "network.entrypoint not found in config.yaml"
    fi
    _ensure_system
    mkdir -p "$HOME/.kube"
    _TEMP_KUBECONFIG="$(mktemp)"
    _TEMP_FILES="$_TEMP_FILES $_TEMP_KUBECONFIG"
    ssh -i "$_SSH_KEY_FILE" -o StrictHostKeyChecking=no admin@"$_MASTER_IP" "sudo cat /etc/kubernetes/admin.conf" > "$_TEMP_KUBECONFIG"
    _TEMP_KUBECONFIG_TMP="$(mktemp)"
    _TEMP_FILES="$_TEMP_FILES $_TEMP_KUBECONFIG_TMP"
    yaml2json < "$_TEMP_KUBECONFIG" | \
        jq ".clusters[0].cluster.server = \"https://$_MASTER_IP:6443\"" | \
        json2yaml > "$_TEMP_KUBECONFIG_TMP"
    mv "$_TEMP_KUBECONFIG_TMP" "$_TEMP_KUBECONFIG"
    _register_kubeconfig "$_TEMP_KUBECONFIG" "$_ENTRYPOINT"
    printf '{"name":"%s","entrypoint":"%s","server":"%s"}\n' "$_CLUSTER" "$_ENTRYPOINT" "$_MASTER_IP" | _format_output "$_FORMAT" cluster
}

_main "$@" 
