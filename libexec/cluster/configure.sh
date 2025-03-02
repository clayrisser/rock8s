#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster apply - apply cluster configuration

SYNOPSIS
       rock8s cluster apply [-h] [-o <format>] <name>

DESCRIPTION
       apply terraform configuration to a kubernetes cluster

ARGUMENTS
       name
              name of the cluster to configure

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _NAME=""
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
                ;;
            -o|--output|-o=*|--output=*)
                case "$1" in
                    *=*)
                        _FORMAT="${1#*=}"
                        shift
                        ;;
                    *)
                        _FORMAT="$2"
                        shift 2
                        ;;
                esac
                ;;
            -*)
                _help
                exit 1
                ;;
            *)
                if [ -z "$_NAME" ]; then
                    _NAME="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done

    [ -z "$_NAME" ] && {
        _fail "cluster name required"
    }

    _CLUSTER_DIR="$(_get_cluster_dir "$_NAME")"
    _CLUSTER_TF_DIR="$_CLUSTER_DIR/terraform/cluster"

    [ ! -d "$_CLUSTER_TF_DIR" ] && {
        _fail "cluster '$_NAME' not initialized. Run 'rock8s cluster init $_NAME' first"
    }

    # Ensure kubeconfig exists
    _KUBECONFIG="$_CLUSTER_DIR/auth/kubeconfig"
    _validate_kubeconfig "$_KUBECONFIG"

    # Apply Terraform configuration
    _ensure_terraform
    cd "$_CLUSTER_TF_DIR"
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan

    printf '{"name":"%s"}\n' "$_NAME" | _format_output "$_FORMAT" cluster
}

_main "$@"
