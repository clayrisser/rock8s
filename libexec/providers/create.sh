#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s providers create - create provider nodes

SYNOPSIS
       rock8s providers create [-h] [-o <format>] <provider> <name>

DESCRIPTION
       create nodes using specified cloud provider

ARGUMENTS
       provider
              name of the provider to use

       name
              name of the cluster to create nodes for

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

ENVIRONMENT
       MASTERS
              space-separated list of master node groups (format: type:count[:key=val,key2=val2])

       WORKERS
              space-separated list of worker node groups (format: type:count[:key=val,key2=val2])

       CLOUD_INIT
              optional cloud-init script

       NETWORK_NAME
              name of the private network (default: private)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _PROVIDER=""
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
                if [ -z "$_PROVIDER" ]; then
                    _PROVIDER="$1"
                    shift
                elif [ -z "$_NAME" ]; then
                    _NAME="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done
    if [ -z "$_PROVIDER" ] || [ -z "$_NAME" ]; then
        _help
        exit 1
    fi
    _ensure_system
    _CONFIG_FILE="$ROCK8S_CONFIG_PATH/clusters/$_NAME"
    if [ -f "$_CONFIG_FILE" ]; then
        . "$_CONFIG_FILE"
    fi
    export PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    export CLUSTER_DIR="$ROCK8S_STATE_HOME/clusters/$_NAME"
    export CLUSTER_NAME="$_NAME"
    : "${NETWORK_NAME:=private}"
    export NETWORK_NAME
    if [ -z "$MASTERS" ]; then
        _fail "MASTERS is required"
    fi
    if [ -z "$WORKERS" ]; then
        _fail "WORKERS is required"
    fi
    export MASTER_GROUPS="$(_parse_node_groups "$MASTERS")"
    export WORKER_GROUPS="$(_parse_node_groups "$WORKERS")"
    if [ ! -d "$PROVIDER_DIR" ]; then
        _fail "provider $_PROVIDER not found"
    fi
    if [ -d "$CLUSTER_DIR" ]; then
        _fail "cluster $_NAME already exists"
    fi
    mkdir -p "$CLUSTER_DIR"
    cp -r "$PROVIDER_DIR" "$CLUSTER_DIR/provider"
    cd "$CLUSTER_DIR/provider"
    _ERROR="$(. "$CLUSTER_DIR/provider/variables.sh" 2>&1)" || {
        _fail "$_ERROR"
    }
    terraform init -backend=true -backend-config="path=$_CLUSTER_DIR/terraform.tfstate" >&2
    terraform apply -auto-approve -state="$_CLUSTER_DIR/terraform.tfstate" >&2
    terraform output -json > "$_CLUSTER_DIR/nodes.json" >&2
    printf '{"name":"%s","provider":"%s"}\n' "$_NAME" "$_PROVIDER" | \
        _format_output "$_FORMAT"
}

_main "$@"
