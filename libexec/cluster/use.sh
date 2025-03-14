#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster use

SYNOPSIS
       rock8s cluster use [-h] [-o <format>] <cluster> [<tenant>]

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
    _ARG1=""
    _ARG2=""
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
                if [ -z "$_ARG1" ]; then
                    _ARG1="$1"
                elif [ -z "$_ARG2" ]; then
                    _ARG2="$1"
                else
                    fail "too many arguments"
                fi
                shift
                ;;
        esac
    done
    if [ -z "$_ARG1" ]; then
        _help
        exit 1
    fi
    _CLUSTER="$_ARG1"
    if [ -n "$_ARG2" ]; then
        _TENANT="$_ARG2"
    else
        _TENANT="$ROCK8S_TENANT"
    fi
    _TENANT_DIR="$ROCK8S_CONFIG_HOME/tenants/$_TENANT"
    _CLUSTER_DIR="$_TENANT_DIR/clusters/$_CLUSTER"
    if [ ! -d "$_TENANT_DIR" ] && [ "$_TENANT" != "default" ]; then
        fail "tenant $_TENANT does not exist"
    fi
    if [ ! -d "$_CLUSTER_DIR" ]; then
        fail "cluster $_CLUSTER does not exist in tenant $_TENANT"
    fi
    mkdir -p "$ROCK8S_STATE_HOME"
    echo "tenant=\"$_TENANT\"" > "$ROCK8S_STATE_HOME/current"
    echo "cluster=\"$_CLUSTER\"" >> "$ROCK8S_STATE_HOME/current"
    printf '{"cluster":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$_TENANT" | \
        format_output "$_OUTPUT" "cluster"
}

_main "$@"
