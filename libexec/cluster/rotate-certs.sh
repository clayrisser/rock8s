#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster rotate-certs

SYNOPSIS
       rock8s cluster rotate-certs [-h] [-o <format>] [--cluster <cluster>]

DESCRIPTION
       rotate k3s certificates on all server nodes and refresh the local kubeconfig

       k3s server certificates are valid for 12 months. this command rotates
       them immediately and restarts k3s on each server node. agent nodes
       automatically receive new certificates when they reconnect.

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -c, --cluster <cluster>
              cluster name

EXAMPLE
       # rotate certificates for a cluster
       rock8s cluster rotate-certs --cluster mycluster

SEE ALSO
       rock8s cluster upgrade --help
       rock8s cluster login --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
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
        -*)
            _help
            exit 1
            ;;
        *)
            _help
            exit 1
            ;;
        esac
    done
    export ROCK8S_CLUSTER="$cluster"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    cluster_dir="$(get_cluster_dir)"
    if [ ! -f "$cluster_dir/kube.yaml" ]; then
        fail "kubeconfig not found, run cluster install first"
    fi
    master_private_ipv4s="$(get_master_private_ipv4s)"
    master_ssh_key="$(get_master_ssh_private_key)"
    for ip in $master_private_ipv4s; do
        log "rotating certificates on server node $ip"
        ssh -o StrictHostKeyChecking=no -i "$master_ssh_key" "$(get_node_ssh_user)@$ip" \
            "sudo k3s certificate rotate && sudo systemctl restart k3s" >&2
    done
    log "waiting for api server to be ready"
    sleep 10
    sh "$ROCK8S_LIBEXEC_PATH/cluster/login.sh" \
        --output="$output" \
        --cluster="$cluster" \
        --kubeconfig "$cluster_dir/kube.yaml" >/dev/null
    log "certificates rotated successfully"
    printf '{"cluster":"%s","provider":"%s"}\n' \
        "$cluster" "$(get_provider)" |
        format_output "$output"
}

_main "$@"
