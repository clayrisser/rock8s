#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster scale - scale cluster nodes

SYNOPSIS
       rock8s cluster scale [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>]

DESCRIPTION
       scale nodes in an existing kubernetes cluster

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to scale (required)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
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
        fail "cluster name required"
    fi
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_TENANT="$_TENANT"
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
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/scale.yml" -b -v
    printf '{"name":"%s"}\n' "$_CLUSTER" | format_output "$_FORMAT" cluster
}

_main "$@"
