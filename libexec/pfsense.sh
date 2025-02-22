#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s pfsense - manage pfSense firewall

SYNOPSIS
       rock8s pfsense [-h] [-o <format>] <command> [<args>]

DESCRIPTION
       configure and manage pfSense firewall

COMMANDS
       configure
              configure pfSense settings and rules

SEE ALSO
       rock8s pfsense configure --help
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CMD=""
    _CMD_ARGS=""
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
            configure)
                _CMD="$1"
                shift
                _CMD_ARGS="$*"
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
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/pfsense/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        _fail "unknown pfsense command: $_CMD"
    fi
    exec sh "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
