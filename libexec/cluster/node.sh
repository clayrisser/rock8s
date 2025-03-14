#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster node

SYNOPSIS
       rock8s cluster node [-h] [-o <format>] <command> [<args>]

DESCRIPTION
       manage kubernetes cluster nodes

COMMANDS
       rm
              remove a node from the cluster

EXAMPLE
       # remove a node from a cluster
       rock8s cluster node rm --cluster mycluster worker-2

SEE ALSO
       rock8s cluster node rm --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _CLUSTER="$ROCK8S_CLUSTER"
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
                        _OUTPUT="${1#*=}"
                        shift
                        ;;
                    *)
                        _OUTPUT="$2"
                        shift 2
                        ;;
                esac
                ;;
            rm)
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
    export ROCK8S_OUTPUT="$_OUTPUT"
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/cluster/node/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        fail "unknown node command: $_CMD"
    fi
    exec sh "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
