#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes ls - list cluster nodes

SYNOPSIS
       rock8s nodes ls [-h] [--cluster <cluster>] [<purpose>]

DESCRIPTION
       list nodes in the cluster

OPTIONS
       -h, --help
              display this help message and exit

       -c, --cluster <cluster>
              cluster name

       -t, --tenant <tenant>
              tenant name

       <purpose>
              filter nodes by purpose:
              - master  : list only master nodes
              - worker  : list only worker nodes
              - pfsense : list only pfsense nodes

EXAMPLE
       # list all nodes in a cluster
       rock8s nodes ls --cluster mycluster

       # list only master nodes
       rock8s nodes ls --cluster mycluster master

       # list only worker nodes with json output
       rock8s nodes ls -o json --cluster mycluster worker

SEE ALSO
       rock8s nodes apply --help
       rock8s nodes destroy --help
       rock8s nodes ssh --help
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _FILTER=""
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
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
            master|worker|pfsense)
                _FILTER="$1"
                shift
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    _MASTER_PRIVATE_IPS="$(get_master_private_ipv4s)"
    _WORKER_PRIVATE_IPS="$(get_worker_private_ipv4s)"
    _PFSENSE_PRIVATE_IPS="$(get_pfsense_private_ipv4s)"
    _MASTER_NODES="{"
    _COUNT=1
    for _NODE in $_MASTER_PRIVATE_IPS; do
        _NODE_NAME="master-$_COUNT"
        [ "$_COUNT" -gt 1 ] && _MASTER_NODES="$_MASTER_NODES,"
        _MASTER_NODES="$_MASTER_NODES\"$_NODE_NAME\":\"$_NODE\""
        _COUNT=$((_COUNT + 1))
    done
    _MASTER_NODES="$_MASTER_NODES}"
    _WORKER_NODES="{"
    _COUNT=1
    for _NODE in $_WORKER_PRIVATE_IPS; do
        _NODE_NAME="worker-$_COUNT"
        [ "$_COUNT" -gt 1 ] && _WORKER_NODES="$_WORKER_NODES,"
        _WORKER_NODES="$_WORKER_NODES\"$_NODE_NAME\":\"$_NODE\""
        _COUNT=$((_COUNT + 1))
    done
    _WORKER_NODES="$_WORKER_NODES}"
    _PFSENSE_NODES="{"
    _COUNT=1
    for _NODE in $_PFSENSE_PRIVATE_IPS; do
        _NODE_NAME="pfsense-$_COUNT"
        [ "$_COUNT" -gt 1 ] && _PFSENSE_NODES="$_PFSENSE_NODES,"
        _PFSENSE_NODES="$_PFSENSE_NODES\"$_NODE_NAME\":\"$_NODE\""
        _COUNT=$((_COUNT + 1))
    done
    _PFSENSE_NODES="$_PFSENSE_NODES}"
    case "$_FILTER" in
        master)
            printf '%s\n' "$_MASTER_NODES" | format_output "$_FORMAT" nodes
            ;;
        worker)
            printf '%s\n' "$_WORKER_NODES" | format_output "$_FORMAT" nodes
            ;;
        pfsense)
            printf '%s\n' "$_PFSENSE_NODES" | format_output "$_FORMAT" nodes
            ;;
        *)
            printf '{"master":%s,"worker":%s,"pfsense":%s}\n' "$_MASTER_NODES" "$_WORKER_NODES" "$_PFSENSE_NODES" | format_output "$_FORMAT" nodes
            ;;
    esac
}

_main "$@"
