#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster install

SYNOPSIS
       rock8s cluster install [-h] [-o <format>] [--cluster <cluster>]

DESCRIPTION
       install kubernetes cluster using k3s

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -c, --cluster <cluster>
              cluster name

EXAMPLE
       # install kubernetes on existing nodes
       rock8s cluster install --cluster mycluster

SEE ALSO
       rock8s cluster apply --help
       rock8s cluster addons --help
       rock8s cluster upgrade --help
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
    master_private_ipv4s="$(get_master_private_ipv4s)"
    first_master="$(get_k3s_first_master_ip)"
    master_ssh_key="$(get_master_ssh_private_key)"
    worker_private_ipv4s="$(get_worker_private_ipv4s)"
    worker_ssh_key="$(get_worker_ssh_private_key)"
    node_ssh_user="$(get_node_ssh_user)"
    k3s_extra_args="$(get_k3s_server_extra_args)"
    if [ -z "$first_master" ]; then
        fail "no master nodes found"
    fi
    master_count="$(get_master_node_count)"
    if [ "$master_count" -gt 1 ]; then
        log "installing k3s in HA mode with $master_count server nodes"
        k3sup install \
            --ip "$first_master" \
            --user "$node_ssh_user" \
            --ssh-key "$master_ssh_key" \
            --cluster \
            --k3s-version "$K3S_VERSION" \
            --k3s-extra-args "$k3s_extra_args" \
            --local-path "$cluster_dir/kube.yaml" >&2
        for ip in $(echo "$master_private_ipv4s" | tail -n +2); do
            log "joining server node $ip"
            k3sup join \
                --ip "$ip" \
                --server-ip "$first_master" \
                --user "$node_ssh_user" \
                --ssh-key "$master_ssh_key" \
                --server \
                --k3s-version "$K3S_VERSION" \
                --k3s-extra-args "$k3s_extra_args" >&2
        done
    else
        log "installing k3s single server"
        k3sup install \
            --ip "$first_master" \
            --user "$node_ssh_user" \
            --ssh-key "$master_ssh_key" \
            --k3s-version "$K3S_VERSION" \
            --k3s-extra-args "$k3s_extra_args" \
            --local-path "$cluster_dir/kube.yaml" >&2
    fi
    for ip in $worker_private_ipv4s; do
        log "joining agent node $ip"
        k3sup join \
            --ip "$ip" \
            --server-ip "$first_master" \
            --user "$node_ssh_user" \
            --ssh-key "$worker_ssh_key" \
            --k3s-version "$K3S_VERSION" >&2
    done
    sh "$ROCK8S_LIBEXEC_PATH/cluster/login.sh" \
        --output="$output" \
        --cluster="$cluster" \
        --kubeconfig "$cluster_dir/kube.yaml" >/dev/null
    printf '{"cluster":"%s","provider":"%s"}\n' \
        "$cluster" "$(get_provider)" |
        format_output "$output"
}

_main "$@"
