#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s providers - manage cloud provider nodes

SYNOPSIS
       rock8s providers [-h] [-o <format>] <command> [<args>]

DESCRIPTION
       manage cloud provider nodes using terraform

COMMANDS
       list
              list available providers

       init
              initialize a provider's terraform configuration

       create
              create nodes using specified provider

       destroy
              destroy nodes for specified provider

SEE ALSO
       rock8s providers list --help
       rock8s providers init --help
       rock8s providers create --help
       rock8s providers destroy --help
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
            list|init|create|destroy)
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
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/providers/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        _fail "unknown providers command: $_CMD"
    fi
    exec "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
