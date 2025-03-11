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
    
    _CLUSTER_DIR="$(_get_cluster_dir "$_TENANT" "$_CLUSTER")"
    
    _CONFIG_FILE="$(_get_cluster_config_file "$_TENANT" "$_CLUSTER")"
    
    _CONFIG_JSON="$(yaml2json < "$_CONFIG_FILE")"
    _ENTRYPOINT="$(_get_cluster_entrypoint "$_CONFIG_JSON")"
    
    # Get node information
    _MASTER_OUTPUT="$(_get_node_output_file "$_CLUSTER_DIR" "master")"
    _MASTER_SSH_PRIVATE_KEY="$(_get_node_ssh_key "$_MASTER_OUTPUT")"
    _MASTER_IPV4="$(_get_node_master_ipv4 "$_MASTER_OUTPUT")"
    
    # Setup kubeconfig
    if [ -z "$_KUBECONFIG" ]; then
        _KUBECONFIG="$HOME/.kube/config"
    fi
    
    _KUBECONFIG_TMP="$(mktemp)"
    _cleanup() {
        rm -f "$_KUBECONFIG_TMP"
    }
    trap _cleanup EXIT
    
    # Get kubeconfig from master node
    ssh -i "$_MASTER_SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "admin@$_MASTER_IPV4" sudo cat /etc/kubernetes/admin.conf > "$_KUBECONFIG_TMP"
    
    # Update server address
    _ENTRYPOINT_IPV4="$(_resolve_hostname "$_ENTRYPOINT")"
    if [ -n "$_ENTRYPOINT_IPV4" ]; then
        sed -i "s/server: https:\/\/[^:]*:/server: https:\/\/$_ENTRYPOINT_IPV4:/" "$_KUBECONFIG_TMP"
    fi
    
    # Update context name
    sed -i "s/kubernetes-admin@kubernetes/$_CLUSTER/" "$_KUBECONFIG_TMP"
    
    # Merge kubeconfig
    if [ -f "$_KUBECONFIG" ]; then
        KUBECONFIG="$_KUBECONFIG:$_KUBECONFIG_TMP" kubectl config view --flatten > "$_KUBECONFIG.tmp"
        mv "$_KUBECONFIG.tmp" "$_KUBECONFIG"
    else
        mkdir -p "$(dirname "$_KUBECONFIG")"
        cp "$_KUBECONFIG_TMP" "$_KUBECONFIG"
    fi
    
    # Use the new context
    kubectl config use-context "$_CLUSTER"
    
    printf '{"name":"%s","entrypoint":"%s","master_ip":"%s","kubeconfig":"%s"}\n' \
        "$_CLUSTER" "$_ENTRYPOINT" "$_MASTER_IPV4" "$_KUBECONFIG" | _format_output "$_FORMAT" cluster
}

_main "$@" 
