#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense

SYNOPSIS
       rock8s pfsense [-h] [-o <format>] [-n|--name <name>] [-t|--tenant <tenant>] <command>

DESCRIPTION
       provision and configure pfsense firewall (standalone, independent of clusters)

COMMANDS
       apply
              provision and configure pfsense firewall nodes

       configure
              configure pfsense settings and rules

       destroy
              destroy pfsense firewall nodes

       publish
              publish cluster haproxy rules to pfsense (requires --cluster)

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -n, --name <name>
              pfsense instance name

EXAMPLE
       # provision and configure pfsense
       rock8s pfsense apply --name mypfsense

       # configure pfsense
       rock8s pfsense configure --name mypfsense

       # publish cluster haproxy rules to pfsense
       rock8s pfsense publish --name mypfsense --cluster mycluster

SEE ALSO
       rock8s pfsense apply --help
       rock8s pfsense configure --help
       rock8s pfsense destroy --help
       rock8s pfsense publish --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    cmd=""
    pfsense="$ROCK8S_PFSENSE"
    tenant="$ROCK8S_TENANT"
    cluster="$ROCK8S_CLUSTER"
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
            -t|--tenant|-t=*|--tenant=*)
                case "$1" in
                    *=*)
                        tenant="${1#*=}"
                        shift
                        ;;
                    *)
                        tenant="$2"
                        shift 2
                        ;;
                esac
                ;;
            -n|--name|-n=*|--name=*)
                case "$1" in
                    *=*)
                        pfsense="${1#*=}"
                        shift
                        ;;
                    *)
                        pfsense="$2"
                        shift 2
                        ;;
                esac
                ;;
            -c|--cluster|-c=*|--cluster=*)
                case "$1" in
                    *=*)
                        cluster="${1#*=}"
                        shift
                        ;;
                    *)
                        cluster="$2"
                        shift 2
                        ;;
                esac
                ;;
            apply|configure|destroy|publish)
                cmd="$1"
                shift
                break
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    if [ -z "$cmd" ]; then
        _help
        exit 1
    fi
    export ROCK8S_OUTPUT="$output"
    export ROCK8S_PFSENSE="$pfsense"
    export ROCK8S_TENANT="$tenant"
    export ROCK8S_CLUSTER="$cluster"
    subcmd="$ROCK8S_LIB_PATH/libexec/pfsense/$cmd.sh"
    if [ ! -f "$subcmd" ]; then
        fail "unknown pfsense command $cmd"
    fi
    exec sh "$subcmd" "$@"
}

_main "$@"
