#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes

SYNOPSIS
       rock8s nodes <command> [<args>]

DESCRIPTION
       create and manage cluster nodes

OPTIONS
       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

COMMANDS
       apply
              create new cluster nodes or update existing ones

       destroy
              destroy cluster nodes

       ls
              list nodes grouped by their purpose

       ssh
              ssh into a specific node

       pubkey
              get public ssh key for nodes

EXAMPLE
       # list all nodes in a cluster
       rock8s nodes ls --cluster mycluster

       # ssh into the first master node
       rock8s nodes ssh master 1

       # create or update worker nodes
       rock8s nodes apply --cluster mycluster worker

       # get public ssh key for master nodes
       rock8s nodes pubkey master

SEE ALSO
       rock8s nodes apply --help
       rock8s nodes destroy --help
       rock8s nodes ls --help
       rock8s nodes ssh --help
       rock8s nodes pubkey --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _CMD=""
    _CMD_ARGS=""
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit
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
            apply|destroy|ls|ssh|pubkey)
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
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_OUTPUT="$_OUTPUT"
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/nodes/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        fail "unknown command: $_CMD"
    fi
    exec sh "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
