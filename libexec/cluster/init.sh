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
    output="${ROCK8S_OUTPUT}"
    tenant="$ROCK8S_TENANT"
    cluster="$ROCK8S_CLUSTER"
    provider=""
    cluster_arg=""
    tenant_arg=""
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
            --provider|--provider=*)
                case "$1" in
                    *=*)
                        provider="${1#*=}"
                        shift
                        ;;
                    *)
                        provider="$2"
                        shift 2
                        ;;
                esac
                ;;
            -*)
                _help
                exit 1
                ;;
            *)
                cluster_arg="$1"
                shift
                if [ $# -gt 0 ] && ! echo "$1" | grep -q "^-"; then
                    tenant_arg="$1"
                    shift
                fi
                break
                ;;
        esac
    done
    if [ -n "$cluster_arg" ]; then
        cluster="$cluster_arg"
    fi
    if [ -n "$tenant_arg" ]; then
        tenant="$tenant_arg"
    fi
    export ROCK8S_TENANT="$tenant"
    export ROCK8S_CLUSTER="$cluster"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    config_dir="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER"
    config_file="$config_dir/config.yaml"
    if [ ! -f "$config_file" ]; then
        get_tenant_config_file >/dev/null
    fi
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","config_file":"%s"}\n' \
        "$cluster" "$(get_provider)" "$tenant" "$config_file" | \
        format_output "$output"
}

_main "$@"
