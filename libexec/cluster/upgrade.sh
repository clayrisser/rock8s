#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster upgrade

SYNOPSIS
       rock8s cluster upgrade [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [-y|--yes]

DESCRIPTION
       upgrade an existing kubernetes cluster

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # upgrade a cluster
       rock8s cluster upgrade --cluster mycluster

       # upgrade a cluster with automatic approval
       rock8s cluster upgrade --cluster mycluster --yes

SEE ALSO
       rock8s cluster install --help
       rock8s cluster addons --help
       rock8s cluster login --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
    tenant="$ROCK8S_TENANT"
    yes=""
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
            -y|--yes)
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
    export ROCK8S_TENANT="$tenant"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    sh "$ROCK8S_LIB_PATH/libexec/nodes/apply.sh" \
        --output="$output" \
        --cluster="$cluster" \
        --tenant="$tenant" \
        $([ "$yes" = "1" ] && echo "--yes") \
        master >/dev/null
    sh "$ROCK8S_LIB_PATH/libexec/nodes/apply.sh" \
        --output="$output" \
        --cluster="$cluster" \
        --tenant="$tenant" \
        $([ "$yes" = "1" ] && echo "--yes") \
        worker >/dev/null
    cluster_dir="$(get_cluster_dir)"
    if [ ! -f "$cluster_dir/kube.yaml" ]; then
        fail "kubeconfig not found, run cluster install first"
    fi
    master_private_ipv4s="$(get_master_private_ipv4s)"
    master_ssh_key="$(get_master_ssh_private_key)"
    worker_private_ipv4s="$(get_worker_private_ipv4s)"
    worker_ssh_key="$(get_worker_ssh_private_key)"
    k3s_install_url="https://get.k3s.io"
    for ip in $master_private_ipv4s; do
        log "upgrading server node $ip to $K3S_VERSION"
        ssh -o StrictHostKeyChecking=no -i "$master_ssh_key" admin@"$ip" \
            "curl -sfL $k3s_install_url | INSTALL_K3S_VERSION=$K3S_VERSION sh -s - server" >&2
    done
    for ip in $worker_private_ipv4s; do
        log "upgrading agent node $ip to $K3S_VERSION"
        ssh -o StrictHostKeyChecking=no -i "$worker_ssh_key" admin@"$ip" \
            "curl -sfL $k3s_install_url | INSTALL_K3S_VERSION=$K3S_VERSION sh -s - agent" >&2
    done
    sh "$ROCK8S_LIB_PATH/libexec/cluster/login.sh" \
        --output="$output" \
        --cluster="$cluster" \
        --tenant="$tenant" \
        --kubeconfig "$cluster_dir/kube.yaml" >/dev/null
    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$cluster" "$(get_provider)" "$tenant" | \
        format_output "$output"
}

_main "$@"
