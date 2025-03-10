#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster node rm - remove node from cluster

SYNOPSIS
       rock8s cluster node rm [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] <node>

DESCRIPTION
       remove a node from an existing kubernetes cluster

ARGUMENTS
       node
              name of the node to remove

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to remove node from (required)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _NODE=""
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
                if [ -z "$_NODE" ]; then
                    _NODE="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done
    if [ -z "$_CLUSTER" ]; then
        _fail "cluster name required"
    fi
    if [ -z "$_NODE" ]; then
        _fail "node name required"
    fi
    
    _CLUSTER_DIR="$(_get_cluster_dir "$_TENANT" "$_CLUSTER")"
    _validate_cluster_dir "$_CLUSTER_DIR"
    
    # Setup Kubespray
    _KUBESPRAY_DIR="$(_get_kubespray_dir "$_CLUSTER_DIR")"
    _validate_kubespray_dir "$_KUBESPRAY_DIR"
    
    _VENV_DIR="$(_get_kubespray_venv_dir "$_KUBESPRAY_DIR")"
    _validate_kubespray_venv "$_VENV_DIR"
    . "$_VENV_DIR/bin/activate"
    
    # Setup inventory
    _INVENTORY_DIR="$(_get_kubespray_inventory_dir "$_CLUSTER_DIR")"
    _validate_kubespray_inventory "$_INVENTORY_DIR"
    
    # Get node information
    _MASTER_SSH_PRIVATE_KEY="$(_get_node_ssh_key "master")"
    
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_INVENTORY_DIR/inventory.ini" \
        -e "@$_INVENTORY_DIR/vars.yml" \
        -e "node=$_NODE" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/remove-node.yml" -b -v
    
    printf '{"cluster":"%s","node":"%s"}\n' "$_CLUSTER" "$_NODE" | _format_output "$_FORMAT" node
}

_main "$@"
