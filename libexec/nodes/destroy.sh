#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s providers destroy - destroy provider nodes

SYNOPSIS
       rock8s providers destroy [-h] [-o <format>] <provider> <name>

DESCRIPTION
       destroy nodes for specified provider and cluster

ARGUMENTS
       provider
              name of the provider to use

       name
              name of the cluster to destroy nodes for

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
    _PROVIDER=""
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
                if [ -z "$_PROVIDER" ]; then
                    _PROVIDER="$1"
                    shift
                elif [ -z "$_NAME" ]; then
                    _NAME="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done

    [ -z "$_PROVIDER" ] && {
        _fail "provider name required"
    }
    [ -z "$_NAME" ] && {
        _fail "cluster name required"
    }

    _CLUSTER_DIR="$(_get_cluster_dir "$_NAME")"
    _TF_DIR="$_CLUSTER_DIR/terraform/$_PROVIDER"

    [ -d "$_TF_DIR" ] || {
        _fail "no terraform state found for cluster '$_NAME' with provider '$_PROVIDER'"
    }

    _ensure_terraform
    cd "$_TF_DIR"

    terraform init
    terraform destroy -auto-approve

    rm -f "$_CLUSTER_DIR/nodes.json"

    printf '{"name":"%s","provider":"%s","status":"destroyed"}\n' "$_NAME" "$_PROVIDER" | \
        _format_output "$_FORMAT" providers
}

_main "$@"
