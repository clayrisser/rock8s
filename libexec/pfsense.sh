#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense

SYNOPSIS
       rock8s pfsense [-h] [-o <format>] [-c|--cluster <cluster>] [-t <tenant>] <command>

DESCRIPTION
       configure and manage pfsense firewall

COMMANDS
       apply
              create and configure pfsense firewall nodes

       configure
              configure pfsense settings and rules

       destroy
              destroy pfsense firewall nodes

       publish
              publish haproxy configuration

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

EXAMPLE
       # create and configure pfsense for a cluster
       rock8s pfsense apply --cluster mycluster

       # configure pfsense for a cluster
       rock8s pfsense configure --cluster mycluster

       # publish haproxy configuration
       rock8s pfsense publish --cluster mycluster --password mypassword

SEE ALSO
       rock8s pfsense apply --help
       rock8s pfsense configure --help
       rock8s pfsense destroy --help
       rock8s pfsense publish --help
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CMD=""
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
            -c|--cluster|-c=*|--cluster=*)
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
            apply|configure|destroy|publish)
                _CMD="$1"
                shift
                break
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    if [ -z "$_CMD" ]; then
        _help
        exit 1
    fi
    export ROCK8S_OUTPUT_FORMAT="$_FORMAT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_TENANT="$_TENANT"
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/pfsense/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        fail "unknown pfsense command: $_CMD"
    fi
    exec sh "$_SUBCMD" "$@"
}

_main "$@"
