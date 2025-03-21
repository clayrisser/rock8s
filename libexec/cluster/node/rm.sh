#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster node rm

SYNOPSIS
       rock8s cluster node rm [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [-y|--yes] <node>

DESCRIPTION
       remove a node from a kubernetes cluster

ARGUMENTS
       node
              name of the node to remove

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # remove a node with confirmation
       rock8s cluster node rm --cluster mycluster worker-2

       # remove a node without confirmation
       rock8s cluster node rm --cluster mycluster --yes worker-3

SEE ALSO
       rock8s cluster node --help
       rock8s nodes ls --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
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
                        _OUTPUT="${1#*=}"
                        shift
                        ;;
                    *)
                        _OUTPUT="$2"
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
            -c|--cluster|-c=*|--cluster=*)
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
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_TENANT="$_TENANT"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    if [ -z "$_NODE" ]; then
        fail "node name required"
    fi
    _CLUSTER_DIR="$(get_cluster_dir)"
    _KUBESPRAY_DIR="$(get_kubespray_dir)"
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        fail "kubespray directory not found"
    fi
    _VENV_DIR="$_KUBESPRAY_DIR/venv"
    if [ ! -d "$_VENV_DIR" ]; then
        fail "kubespray virtual environment not found"
    fi
    . "$_VENV_DIR/bin/activate"
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_CLUSTER_DIR/inventory/inventory.ini" \
        -e "@$_CLUSTER_DIR/inventory/vars.yml" \
        -e "node=$_NODE" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/remove-node.yml" -b -v >&2
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","node":"%s"}\n' \
        "$_CLUSTER" "$(get_provider)" "$_TENANT" "$_NODE" | \
        format_output "$_OUTPUT"
}

_main "$@"
