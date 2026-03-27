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
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
    cmd=""
    cmd_args=""
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
            rm)
                cmd="$1"
                shift
                cmd_args="$*"
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
    subcmd="$ROCK8S_LIB_PATH/libexec/cluster/node/$cmd.sh"
    if [ ! -f "$subcmd" ]; then
        fail "unknown node command: $cmd"
    fi
    exec sh "$subcmd" $cmd_args
}

_main "$@"
