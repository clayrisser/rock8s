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
       rock8s cluster addons --help
       rock8s cluster login --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT:-json}"
    cmd=""
    cluster=""
    tenant=""
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit
                ;;
            -o|--output|-o=*|--output=*)
                case "$1" in
                    *=*)
                        output="${1#*=}"
                        shift
                        ;;
                    *)
                        output="$2"
                        shift 2
                        ;;
                esac
                ;;
            *)
                if [ -z "$cluster" ]; then
                    cluster="$1"
                    shift
                elif [ -z "$tenant" ]; then
                    tenant="$1"
                    shift
                else
                    fail "too many arguments"
                fi
                ;;
        esac
    done
    if [ -n "$cluster" ]; then
        export ROCK8S_CLUSTER="$cluster"
    fi
    if [ -n "$tenant" ]; then
        export ROCK8S_TENANT="$tenant"
    fi
    tenant_dir="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT"
    cluster_dir="$tenant_dir/clusters/$ROCK8S_CLUSTER"
    if [ ! -d "$tenant_dir" ] && [ "$ROCK8S_TENANT" != "default" ]; then
        fail "tenant $ROCK8S_TENANT does not exist"
    fi
    if [ ! -d "$cluster_dir" ]; then
        fail "cluster $ROCK8S_CLUSTER does not exist in tenant $ROCK8S_TENANT"
    fi
    mkdir -p "$ROCK8S_STATE_HOME"
    echo "tenant=\"$ROCK8S_TENANT\"" > "$ROCK8S_STATE_HOME/current"
    echo "cluster=\"$ROCK8S_CLUSTER\"" >> "$ROCK8S_STATE_HOME/current"
    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$ROCK8S_CLUSTER" "$(get_provider)" "$ROCK8S_TENANT" | \
        format_output "$output"
}

_main "$@"
