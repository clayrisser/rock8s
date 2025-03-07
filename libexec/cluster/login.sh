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
       rock8s cluster login [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--kubeconfig <path>]

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

       --kubeconfig <path>
              path to the kubeconfig file (default: $HOME/.kube/config)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _KUBECONFIG="$HOME/.kube/config"
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
            --kubeconfig|--kubeconfig=*)
                case "$1" in
                    *=*)
                        _KUBECONFIG="${1#*=}"
                        shift
                        ;;
                    *)
                        _KUBECONFIG="$2"
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
    _MASTER_IPV4="$(grep -A1 '\[kube_control_plane\]' "$_INVENTORY_FILE" | tail -n1 | grep -o 'ansible_host=[^ ]*' | cut -d'=' -f2)"
    if [ -z "$_MASTER_IPV4" ]; then
        _fail "master node not found in inventory file"
    fi
    _SSH_KEY_FILE="$(jq -r '.node_ssh_private_key.value' "$_MASTER_OUTPUT")"
    if [ -z "$_SSH_KEY_FILE" ] || [ "$_SSH_KEY_FILE" = "null" ]; then
        _fail "ssh key not found in output.json"
    fi
    _ENTRYPOINT="$(yaml2json < "$_CONFIG_FILE" | jq -r '.network.entrypoint')"
    if [ -z "$_ENTRYPOINT" ] || [ "$_ENTRYPOINT" = "null" ]; then
        _fail "network.entrypoint not found in config.yaml"
    fi
    _ensure_system
    mkdir -p "$(dirname "$_KUBECONFIG")"
    _TEMP_KUBECONFIG="$(mktemp)"
    _TEMP_FILES="$_TEMP_FILES $_TEMP_KUBECONFIG"
    ssh -i "$_SSH_KEY_FILE" -o StrictHostKeyChecking=no admin@"$_MASTER_IPV4" "sudo cat /etc/kubernetes/admin.conf" > "$_TEMP_KUBECONFIG"
    jq '.clusters[0].cluster.server = "https://'$_ENTRYPOINT':6443"' "$_TEMP_KUBECONFIG" | \
        jq ".clusters[0].cluster.server = \"https://$_MASTER_IPV4:6443\"" | \
        jq '.clusters[0].name = "'$_CLUSTER'" | .contexts[0].name = "'$_CLUSTER'" | .contexts[0].context.cluster = "'$_CLUSTER'" | .contexts[0].context.user = "'$_CLUSTER'" | .current-context = "'$_CLUSTER'" | .users[0].name = "'$_CLUSTER'"' > "$_KUBECONFIG"
    chmod 600 "$_KUBECONFIG"
    printf '{"name":"%s","entrypoint":"%s","server":"%s","kubeconfig":"%s"}\n' "$_CLUSTER" "$_ENTRYPOINT" "$_MASTER_IPV4" "$_KUBECONFIG" | _format_output "$_FORMAT" cluster
}

_main "$@" 
