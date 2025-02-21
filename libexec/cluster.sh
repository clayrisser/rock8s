#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s cluster - manage kubernetes clusters

SYNOPSIS
       rock8s cluster [-h] [-o <format>] <command> [<args>]

DESCRIPTION
       create and manage kubernetes clusters

COMMANDS
       create
              create a new kubernetes cluster

       configure
              configure an existing cluster with operators

       upgrade
              upgrade an existing cluster

       node
              manage cluster nodes

       reset
              reset/remove the cluster

SEE ALSO
       rock8s cluster create --help
       rock8s cluster configure --help
       rock8s cluster upgrade --help
       rock8s cluster node --help
       rock8s cluster reset --help
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
            create|configure|upgrade|node|reset)
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
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/cluster/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        _fail "unknown cluster command: $_CMD"
    fi
    exec "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
