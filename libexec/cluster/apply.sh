#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster apply

SYNOPSIS
       rock8s cluster apply [-h] [-o <format>] [--cluster <cluster>] [--update] [-y|--yes] [--skip-k3s] [--skip-nodes]

DESCRIPTION
       create nodes, install and configure kubernetes cluster in a single command

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -c, --cluster <cluster>
              cluster name

       --update
              update addons repository

       -y, --yes
              skip confirmation prompt

       --skip-k3s
              skip k3s installation

       --skip-nodes
              skip nodes installation

EXAMPLE
       # apply a cluster with automatic approval
       rock8s cluster apply --cluster mycluster --yes

SEE ALSO
       rock8s cluster install --help
       rock8s cluster addons --help
       rock8s cluster upgrade --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
    update=""
    yes="0"
    skip_nodes=""
    skip_k3s=""
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
        --update)
            update="1"
            shift
            ;;
        -y | --yes)
            yes="1"
            shift
            ;;
        --skip-k3s)
            skip_k3s="1"
            shift
            ;;
        --skip-nodes)
            skip_nodes="1"
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
    if [ "$skip_nodes" != "1" ]; then
        sh "$ROCK8S_LIBEXEC_PATH/nodes/apply.sh" \
            --output="$output" \
            --cluster="$cluster" \
            $([ "$yes" = "1" ] && echo "--yes") \
            master >/dev/null
        sh "$ROCK8S_LIBEXEC_PATH/nodes/apply.sh" \
            --output="$output" \
            --cluster="$cluster" \
            $([ "$yes" = "1" ] && echo "--yes") \
            worker >/dev/null
    fi
    if [ "$skip_k3s" != "1" ]; then
        sleep 90
        if [ ! -f "$cluster_dir/kube.yaml" ]; then
            sh "$ROCK8S_LIBEXEC_PATH/cluster/install.sh" \
                --output="$output" \
                --cluster="$cluster" \
                $([ "$yes" = "1" ] && echo "--yes") >/dev/null
        else
            sh "$ROCK8S_LIBEXEC_PATH/cluster/upgrade.sh" \
                --output="$output" \
                --cluster="$cluster" \
                $([ "$yes" = "1" ] && echo "--yes") >/dev/null
        fi
    fi
    sh "$ROCK8S_LIBEXEC_PATH/cluster/addons.sh" \
        --output="$output" \
        --cluster="$cluster" \
        $([ "$update" = "1" ] && echo "--update") \
        $([ "$yes" = "1" ] && echo "--yes") >/dev/null
    printf '{"cluster":"%s","provider":"%s"}\n' \
        "$cluster" "$(get_provider)" |
        format_output "$output"
}

_main "$@"
