#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes ls

SYNOPSIS
       rock8s nodes ls [-h] [--cluster <cluster>] [<purpose>]

DESCRIPTION
       list nodes in the cluster

OPTIONS
       -h, --help
              display this help message and exit

       -o, --output=<format>
              output format (json, yaml, text)

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
    _OUTPUT="${ROCK8S_OUTPUT}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _FILTER=""
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
    export ROCK8S_OUTPUT="$_OUTPUT"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    _MASTER_PRIVATE_IPS="$(get_master_private_ipv4s 2>/dev/null || echo "")"
    _WORKER_PRIVATE_IPS="$(get_worker_private_ipv4s 2>/dev/null || echo "")"
    _PFSENSE_PRIVATE_IPS="$(get_pfsense_private_ipv4s 2>/dev/null || echo "")"
    _PFSENSE_NODES="["
    _COUNT=1
    for _NODE in $_PFSENSE_PRIVATE_IPS; do
        [ -z "$_NODE" ] && continue
        _NODE_NAME="pfsense-$_COUNT"
        [ "$_COUNT" -gt 1 ] && _PFSENSE_NODES="$_PFSENSE_NODES,"
        _PFSENSE_NODES="$_PFSENSE_NODES{\"purpose\":\"pfsense\",\"name\":\"$_NODE_NAME\",\"lan_ipv4\":\"$_NODE\"}"
        _COUNT=$((_COUNT + 1))
    done
    _PFSENSE_NODES="$_PFSENSE_NODES]"
    _MASTER_NODES="["
    _COUNT=1
    for _NODE in $_MASTER_PRIVATE_IPS; do
        [ -z "$_NODE" ] && continue
        _NODE_NAME="master-$_COUNT"
        [ "$_COUNT" -gt 1 ] && _MASTER_NODES="$_MASTER_NODES,"
        _MASTER_NODES="$_MASTER_NODES{\"purpose\":\"master\",\"name\":\"$_NODE_NAME\",\"lan_ipv4\":\"$_NODE\"}"
        _COUNT=$((_COUNT + 1))
    done
    _MASTER_NODES="$_MASTER_NODES]"
    _WORKER_NODES="["
    _COUNT=1
    for _NODE in $_WORKER_PRIVATE_IPS; do
        [ -z "$_NODE" ] && continue
        _NODE_NAME="worker-$_COUNT"
        [ "$_COUNT" -gt 1 ] && _WORKER_NODES="$_WORKER_NODES,"
        _WORKER_NODES="$_WORKER_NODES{\"purpose\":\"worker\",\"name\":\"$_NODE_NAME\",\"lan_ipv4\":\"$_NODE\"}"
        _COUNT=$((_COUNT + 1))
    done
    _WORKER_NODES="$_WORKER_NODES]"
    case "$_FILTER" in
        master)
            printf '%s\n' "$_MASTER_NODES" | format_output "$_OUTPUT" nodes
            ;;
        worker)
            printf '%s\n' "$_WORKER_NODES" | format_output "$_OUTPUT" nodes
            ;;
        pfsense)
            printf '%s\n' "$_PFSENSE_NODES" | format_output "$_OUTPUT" nodes
            ;;
        *)
            _ALL_NODES="["
            _NODE_COUNT=0
            _FIRST_PFSENSE=1
            for _NODE in $_PFSENSE_PRIVATE_IPS; do
                [ -z "$_NODE" ] && continue
                _NODE_NAME="pfsense-$_FIRST_PFSENSE"
                [ "$_NODE_COUNT" -gt 0 ] && _ALL_NODES="$_ALL_NODES,"
                _ALL_NODES="$_ALL_NODES{\"purpose\":\"pfsense\",\"name\":\"$_NODE_NAME\",\"lan_ipv4\":\"$_NODE\"}"
                _FIRST_PFSENSE=$((_FIRST_PFSENSE + 1))
                _NODE_COUNT=$((_NODE_COUNT + 1))
            done
            _FIRST_MASTER=1
            for _NODE in $_MASTER_PRIVATE_IPS; do
                [ -z "$_NODE" ] && continue
                _NODE_NAME="master-$_FIRST_MASTER"
                [ "$_NODE_COUNT" -gt 0 ] && _ALL_NODES="$_ALL_NODES,"
                _ALL_NODES="$_ALL_NODES{\"purpose\":\"master\",\"name\":\"$_NODE_NAME\",\"lan_ipv4\":\"$_NODE\"}"
                _FIRST_MASTER=$((_FIRST_MASTER + 1))
                _NODE_COUNT=$((_NODE_COUNT + 1))
            done
            _FIRST_WORKER=1
            for _NODE in $_WORKER_PRIVATE_IPS; do
                [ -z "$_NODE" ] && continue
                _NODE_NAME="worker-$_FIRST_WORKER"
                [ "$_NODE_COUNT" -gt 0 ] && _ALL_NODES="$_ALL_NODES,"
                _ALL_NODES="$_ALL_NODES{\"purpose\":\"worker\",\"name\":\"$_NODE_NAME\",\"lan_ipv4\":\"$_NODE\"}"
                _FIRST_WORKER=$((_FIRST_WORKER + 1))
                _NODE_COUNT=$((_NODE_COUNT + 1))
            done
            _ALL_NODES="$_ALL_NODES]"
            printf '%s\n' "$_ALL_NODES" | format_output "$_OUTPUT" nodes
            ;;
    esac
}

_main "$@"
