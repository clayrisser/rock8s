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
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
    tenant="$ROCK8S_TENANT"
    filter=""
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
            master|worker)
                filter="$1"
                shift
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    export ROCK8S_TENANT="$tenant"
    export ROCK8S_CLUSTER="$cluster"
    export ROCK8S_OUTPUT="$output"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    master_private_ips="$(get_master_private_ipv4s)"
    worker_private_ips="$(get_worker_private_ipv4s)"
    master_nodes="["
    count=1
    for node in $master_private_ips; do
        [ -z "$node" ] && continue
        node_name="master-$count"
        [ "$count" -gt 1 ] && master_nodes="$master_nodes,"
        master_nodes="$master_nodes{\"purpose\":\"master\",\"name\":\"$node_name\",\"lan_ipv4\":\"$node\"}"
        count=$((count + 1))
    done
    master_nodes="$master_nodes]"
    worker_nodes="["
    count=1
    for node in $worker_private_ips; do
        [ -z "$node" ] && continue
        node_name="worker-$count"
        [ "$count" -gt 1 ] && worker_nodes="$worker_nodes,"
        worker_nodes="$worker_nodes{\"purpose\":\"worker\",\"name\":\"$node_name\",\"lan_ipv4\":\"$node\"}"
        count=$((count + 1))
    done
    worker_nodes="$worker_nodes]"
    case "$filter" in
        master)
            printf '%s\n' "$master_nodes" | format_output "$output" nodes
            ;;
        worker)
            printf '%s\n' "$worker_nodes" | format_output "$output" nodes
            ;;
        *)
            all_nodes="["
            node_count=0
            first_master=1
            for node in $master_private_ips; do
                [ -z "$node" ] && continue
                node_name="master-$first_master"
                [ "$node_count" -gt 0 ] && all_nodes="$all_nodes,"
                all_nodes="$all_nodes{\"purpose\":\"master\",\"name\":\"$node_name\",\"lan_ipv4\":\"$node\"}"
                first_master=$((first_master + 1))
                node_count=$((node_count + 1))
            done
            first_worker=1
            for node in $worker_private_ips; do
                [ -z "$node" ] && continue
                node_name="worker-$first_worker"
                [ "$node_count" -gt 0 ] && all_nodes="$all_nodes,"
                all_nodes="$all_nodes{\"purpose\":\"worker\",\"name\":\"$node_name\",\"lan_ipv4\":\"$node\"}"
                first_worker=$((first_worker + 1))
                node_count=$((node_count + 1))
            done
            all_nodes="$all_nodes]"
            printf '%s\n' "$all_nodes" | format_output "$output" nodes
            ;;
    esac
}

_main "$@"
