#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster use

SYNOPSIS
       rock8s cluster use [-h] [-o <format>] [<cluster>] [<tenant>]

DESCRIPTION
       select a default cluster and tenant for subsequent commands

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

ARGUMENTS
       <cluster>
              name of the cluster to use

       <tenant>
              tenant name

EXAMPLE
       # select a default cluster
       rock8s cluster use mycluster

       # select a default cluster with a specific tenant
       rock8s cluster use mycluster mytenant

       # select a default cluster with yaml output
       rock8s cluster use -o yaml mycluster

SEE ALSO
       rock8s cluster install --help
       rock8s cluster configure --help
       rock8s cluster login --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT:-json}"
    _CMD=""
    _CLUSTER=""
    _TENANT=""
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
            *)
                if [ -z "$_CLUSTER" ]; then
                    _CLUSTER="$1"
                    shift
                elif [ -z "$_TENANT" ]; then
                    _TENANT="$1"
                    shift
                else
                    fail "too many arguments"
                fi
                ;;
        esac
    done
    if [ -n "$_CLUSTER" ]; then
        export ROCK8S_CLUSTER="$_CLUSTER"
    fi
    if [ -n "$_TENANT" ]; then
        export ROCK8S_TENANT="$_TENANT"
    fi
    _TENANT_DIR="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT"
    _CLUSTER_DIR="$_TENANT_DIR/clusters/$ROCK8S_CLUSTER"
    if [ ! -d "$_TENANT_DIR" ] && [ "$ROCK8S_TENANT" != "default" ]; then
        fail "tenant $ROCK8S_TENANT does not exist"
    fi
    if [ ! -d "$_CLUSTER_DIR" ]; then
        fail "cluster $ROCK8S_CLUSTER does not exist in tenant $ROCK8S_TENANT"
    fi
    mkdir -p "$ROCK8S_STATE_HOME"
    echo "tenant=\"$ROCK8S_TENANT\"" > "$ROCK8S_STATE_HOME/current"
    echo "cluster=\"$ROCK8S_CLUSTER\"" >> "$ROCK8S_STATE_HOME/current"
    printf '{"cluster":"%s","tenant":"%s"}\n' \
        "$ROCK8S_CLUSTER" "$ROCK8S_TENANT" | \
        format_output "$_OUTPUT" "cluster"
}

_main "$@"
