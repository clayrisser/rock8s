#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense - manage pfSense firewall

SYNOPSIS
       rock8s pfsense [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] <command>

DESCRIPTION
       configure and manage pfSense firewall

COMMANDS
       configure
              configure pfSense settings and rules

       destroy
              destroy pfSense firewall nodes

       publish
              publish HAProxy configuration

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to manage pfSense for

SEE ALSO
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
            --cluster|--cluster=*)
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
            configure|destroy|publish)
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
        _fail "unknown pfsense command: $_CMD"
    fi
    exec sh "$_SUBCMD" "$@"
}

_main "$@"
