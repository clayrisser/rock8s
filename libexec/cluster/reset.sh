#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster reset - reset kubernetes cluster

SYNOPSIS
       rock8s cluster reset [-h] [-o <format>] <name>

DESCRIPTION
       reset/remove an existing kubernetes cluster

ARGUMENTS
       name
              name of the cluster to reset

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

    _log "Running Kubespray reset playbook..."
    ansible-playbook -i "$_KUBESPRAY_CLUSTER_DIR/inventory.yml" \
        "$ROCK8S_KUBESPRAY_PATH/reset.yml" \
        -b -v "$@"

    printf '{"name":"%s"}\n' "$_NAME" | _format_output "$_FORMAT" cluster
}

_main "$@"
