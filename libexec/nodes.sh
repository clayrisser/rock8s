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
    output="${ROCK8S_OUTPUT}"
    cmd=""
    cmd_args=""
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
            apply|destroy|ls|ssh|pubkey)
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
    export ROCK8S_TENANT="$tenant"
    export ROCK8S_CLUSTER="$cluster"
    export ROCK8S_OUTPUT="$output"
    subcmd="$ROCK8S_LIB_PATH/libexec/nodes/$cmd.sh"
    if [ ! -f "$subcmd" ]; then
        fail "unknown command: $cmd"
    fi
    exec sh "$subcmd" $cmd_args
}

_main "$@"
