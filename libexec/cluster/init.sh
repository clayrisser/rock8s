#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster init

SYNOPSIS
       rock8s cluster init [-h] [-o <format>] [--provider <provider>] [<cluster> [<tenant>]]

DESCRIPTION
       initialize the configuration for a cluster

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       --provider <provider>
              cloud provider to use (e.g., hetzner)

ARGUMENTS
       <cluster>
              cluster name

       <tenant>
              tenant name

EXAMPLE
       # initialize a new cluster
       rock8s cluster init mycluster

       # initialize a cluster with a specific tenant
       rock8s cluster init mycluster mytenant

       # initialize a cluster with a specific provider
       rock8s cluster init mycluster --provider hetzner

SEE ALSO
       rock8s cluster apply --help
       rock8s cluster addons --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _PROVIDER=""
    _CLUSTER_ARG=""
    _TENANT_ARG=""
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
            --provider|--provider=*)
                case "$1" in
                    *=*)
                        _PROVIDER="${1#*=}"
                        shift
                        ;;
                    *)
                        _PROVIDER="$2"
                        shift 2
                        ;;
                esac
                ;;
            -*)
                _help
                exit 1
                ;;
            *)
                _CLUSTER_ARG="$1"
                shift
                if [ $# -gt 0 ] && ! echo "$1" | grep -q "^-"; then
                    _TENANT_ARG="$1"
                    shift
                fi
                break
                ;;
        esac
    done
    if [ -n "$_CLUSTER_ARG" ]; then
        _CLUSTER="$_CLUSTER_ARG"
    fi
    if [ -n "$_TENANT_ARG" ]; then
        _TENANT="$_TENANT_ARG"
    fi
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    _CONFIG_DIR="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER"
    _CONFIG_FILE="$_CONFIG_DIR/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        get_tenant_config_file >/dev/null
    fi
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","config_file":"%s"}\n' \
        "$_CLUSTER" "$(get_provider)" "$_TENANT" "$_CONFIG_FILE" | \
        format_output "$_OUTPUT"
}

_main "$@"
