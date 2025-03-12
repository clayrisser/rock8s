#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster node rm - remove node from cluster

SYNOPSIS
       rock8s cluster node rm [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [-y|--yes] <node>

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

       -y, --yes
              skip confirmation prompt
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _NODE=""
    _YES=""
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
            -y|--yes)
                _YES="1"
                shift
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
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_TENANT="$_TENANT"
    _CLUSTER_DIR="$(_get_cluster_dir)"
    _KUBESPRAY_DIR="$(_get_kubespray_dir)"
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        _fail "kubespray directory not found"
    fi
    _VENV_DIR="$_KUBESPRAY_DIR/venv"
    if [ ! -d "$_VENV_DIR" ]; then
        _fail "kubespray virtual environment not found"
    fi
    . "$_VENV_DIR/bin/activate"
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_CLUSTER_DIR/inventory/inventory.ini" \
        -e "@$_CLUSTER_DIR/inventory/vars.yml" \
        -e "node=$_NODE" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/remove-node.yml" -b -v
    
    printf '{"cluster":"%s","node":"%s"}\n' "$_CLUSTER" "$_NODE" | _format_output "$_FORMAT" node
}

_main "$@"
