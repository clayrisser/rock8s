#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

export KUBESPRAY_VERSION="${KUBESPRAY_VERSION:-v2.24.0}"
export KUBESPRAY_REPO="${KUBESPRAY_REPO:-https://github.com/kubernetes-sigs/kubespray.git}"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster - manage kubernetes clusters

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
       configure
              configure an existing cluster with operators

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

       use
              select a default cluster for subsequent commands

EXAMPLE
       # install a new kubernetes cluster
       rock8s cluster install --cluster mycluster --yes

       # configure with operators after installation
       rock8s cluster configure --cluster mycluster

       # set a default cluster for other commands
       rock8s cluster use mycluster mytenant

       # login to an existing cluster
       rock8s cluster login --cluster mycluster

SEE ALSO
       rock8s cluster configure --help
       rock8s cluster install --help
       rock8s cluster upgrade --help
       rock8s cluster node --help
       rock8s cluster scale --help
       rock8s cluster login --help
       rock8s cluster reset --help
       rock8s cluster use --help
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CMD=""
    _CMD_ARGS=""
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
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
            configure|install|upgrade|node|scale|login|reset|use)
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
    export ROCK8S_CLUSTER="$_CLUSTER"
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/cluster/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        fail "unknown cluster command: $_CMD"
    fi
    exec sh "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
