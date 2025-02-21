#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s cluster node add - add nodes to cluster

SYNOPSIS
       rock8s cluster node add [-h] [-o <format>] <name>

DESCRIPTION
       add nodes to an existing kubernetes cluster

ARGUMENTS
       name
              name of the cluster to add nodes to

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _NAME=""
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
            -*)
                _help
                exit 1
                ;;
            *)
                if [ -z "$_NAME" ]; then
                    _NAME="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done

    [ -z "$_NAME" ] && {
        _fail "cluster name required"
    }

    _CLUSTER_DIR="$(_get_cluster_dir "$_NAME")"
    _KUBESPRAY_CLUSTER_DIR="$_CLUSTER_DIR/kubespray"

    [ ! -d "$_KUBESPRAY_CLUSTER_DIR" ] && {
        _fail "cluster '$_NAME' not found"
    }

    # Activate virtual environment
    . "$_KUBESPRAY_CLUSTER_DIR/venv/bin/activate"

    # Check if we have updated nodes.json from a provider
    if [ -f "$_CLUSTER_DIR/nodes.json" ]; then
        _log "Updating inventory from nodes.json..."
        python "$ROCK8S_LIB_PATH/libexec/kubespray/generate_inventory.py" \
            --nodes "$_CLUSTER_DIR/nodes.json" \
            --output "$_KUBESPRAY_CLUSTER_DIR/inventory.yml"
    fi

    _log "Running Kubespray scale playbook..."
    ansible-playbook -i "$_KUBESPRAY_CLUSTER_DIR/inventory.yml" \
        "$ROCK8S_KUBESPRAY_PATH/scale.yml" \
        -b -v "$@"

    printf '{"name":"%s","status":"nodes_added"}\n' "$_NAME" | _format_output "$_FORMAT" cluster
}

_main "$@"
