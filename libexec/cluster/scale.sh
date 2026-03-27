#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster scale

SYNOPSIS
       rock8s cluster scale [-h] [-o <format>] [--cluster <cluster>]

DESCRIPTION
       scale nodes in a kubernetes cluster by joining new worker nodes

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -c, --cluster <cluster>
              cluster name

EXAMPLE
       # scale a cluster
       rock8s cluster scale --cluster mycluster

SEE ALSO
       rock8s cluster node --help
       rock8s cluster addons --help
       rock8s cluster apply --help
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
    first_master="$(get_k3s_first_master_ip)"
    node_ssh_user="$(get_node_ssh_user)"
    worker_ssh_key="$(get_worker_ssh_private_key)"
    worker_private_ipv4s="$(get_worker_private_ipv4s)"
    if [ -z "$first_master" ]; then
        fail "no master nodes found"
    fi
    for ip in $worker_private_ipv4s; do
        already_joined="$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            -i "$worker_ssh_key" "$node_ssh_user@$ip" \
            'systemctl is-active k3s-agent 2>/dev/null || true')" || true
        if [ "$already_joined" = "active" ]; then
            log "node $ip already joined, skipping"
            continue
        fi
        log "joining agent node $ip"
        k3sup join \
            --ip "$ip" \
            --server-ip "$first_master" \
            --user "$node_ssh_user" \
            --ssh-key "$worker_ssh_key" \
            --k3s-version "$K3S_VERSION" >&2
    done
    printf '{"cluster":"%s","provider":"%s"}\n' \
        "$cluster" "$(get_provider)" |
        format_output "$output"
}

_main "$@"
