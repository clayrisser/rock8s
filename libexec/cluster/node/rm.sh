#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster node rm

SYNOPSIS
       rock8s cluster node rm [-h] [-o <format>] [--cluster <cluster>] [-y|--yes] <node>

DESCRIPTION
       remove a node from a kubernetes cluster

ARGUMENTS
       node
              name of the node to remove

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -c, --cluster <cluster>
              cluster name

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # remove a node with confirmation
       rock8s cluster node rm --cluster mycluster worker-2

       # remove a node without confirmation
       rock8s cluster node rm --cluster mycluster --yes worker-3

SEE ALSO
       rock8s cluster node --help
       rock8s nodes ls --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
    node=""
    yes=""
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
        -y | --yes)
            yes="1"
            shift
            ;;
        -*)
            _help
            exit 1
            ;;
        *)
            if [ -z "$node" ]; then
                node="$1"
                shift
            else
                _help
                exit 1
            fi
            ;;
        esac
    done
    export ROCK8S_CLUSTER="$cluster"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    if [ -z "$node" ]; then
        fail "node name required"
    fi
    cluster_dir="$(get_cluster_dir)"
    kube_config="$cluster_dir/kube.yaml"
    if [ ! -f "$kube_config" ]; then
        fail "kubeconfig not found"
    fi
    log "draining node $node"
    kubectl --kubeconfig="$kube_config" drain "$node" \
        --ignore-daemonsets --delete-emptydir-data --force 2>&2 || true
    log "deleting node $node from cluster"
    kubectl --kubeconfig="$kube_config" delete node "$node" >&2 || true
    printf '{"cluster":"%s","provider":"%s","node":"%s"}\n' \
        "$cluster" "$(get_provider)" "$node" |
        format_output "$output"
}

_main "$@"
