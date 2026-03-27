#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

export K3S_VERSION="${K3S_VERSION:-v1.31.4+k3s1}"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster

SYNOPSIS
       rock8s cluster [-h] [-o <format>] [-c|--cluster <cluster>] <command> [<args>]

DESCRIPTION
       create and manage kubernetes clusters

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -c, --cluster <cluster>
              cluster name

COMMANDS
       apply
              create nodes, install and configure a kubernetes cluster in one step

       addons
              configure cluster addons for an existing kubernetes cluster

       install
              install kubernetes on a cluster

       upgrade
              upgrade an existing cluster

       node
              manage cluster nodes

       scale
              scale cluster nodes

       login
              login to a kubernetes cluster

       reset
              reset/remove the cluster

       rotate-certs
              rotate k3s certificates on server nodes

EXAMPLE
       # create and setup a new kubernetes cluster in one step
       rock8s cluster apply --cluster mycluster --yes

       # install kubernetes on existing nodes
       rock8s cluster install --cluster mycluster --yes

       # configure addons after installation
       rock8s cluster addons --cluster mycluster

       # login to an existing cluster
       rock8s cluster login --cluster mycluster

       # rotate k3s certificates
       rock8s cluster rotate-certs --cluster mycluster

SEE ALSO
       rock8s cluster apply --help
       rock8s cluster addons --help
       rock8s cluster install --help
       rock8s cluster upgrade --help
       rock8s cluster node --help
       rock8s cluster scale --help
       rock8s cluster login --help
       rock8s cluster reset --help
       rock8s cluster rotate-certs --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
    cmd=""
    cmd_args=""
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            _help
            exit
            ;;
        -o | --output | -o=* | --output=*)
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
        -c | --cluster | -c=* | --cluster=*)
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
        apply | addons | install | upgrade | node | scale | login | reset | rotate-certs)
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
    export ROCK8S_CLUSTER="$cluster"
    subcmd="$ROCK8S_LIBEXEC_PATH/cluster/$cmd.sh"
    if [ ! -f "$subcmd" ]; then
        fail "unknown cluster command: $cmd"
    fi
    exec sh "$subcmd" $cmd_args
}

_main "$@"
