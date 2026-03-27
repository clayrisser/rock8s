#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster reset

SYNOPSIS
       rock8s cluster reset [-h] [-o <format>] [--cluster <cluster>] [-y|--yes]

DESCRIPTION
       reset kubernetes cluster by uninstalling k3s from all nodes

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
       # reset a cluster with confirmation
       rock8s cluster reset --cluster mycluster

       # reset a cluster without confirmation
       rock8s cluster reset --cluster mycluster --yes

SEE ALSO
       rock8s cluster install --help
       rock8s cluster addons --help
       rock8s nodes destroy --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
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
    worker_private_ipv4s="$(get_worker_private_ipv4s)"
    worker_ssh_key="$(get_worker_ssh_private_key)"
    master_private_ipv4s="$(get_master_private_ipv4s)"
    master_ssh_key="$(get_master_ssh_private_key)"
    for ip in $worker_private_ipv4s; do
        log "uninstalling k3s agent on $ip"
        ssh -o StrictHostKeyChecking=no -i "$worker_ssh_key" "$(get_node_ssh_user)@$ip" \
            'sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true' >&2
    done
    for ip in $master_private_ipv4s; do
        log "uninstalling k3s server on $ip"
        ssh -o StrictHostKeyChecking=no -i "$master_ssh_key" "$(get_node_ssh_user)@$ip" \
            'sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true' >&2
    done
    rm -f "$cluster_dir/kube.yaml"
    printf '{"cluster":"%s","provider":"%s"}\n' \
        "$cluster" "$(get_provider)" |
        format_output "$output"
}

_main "$@"
