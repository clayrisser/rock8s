#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s providers create - create provider nodes

SYNOPSIS
       rock8s providers create [-h] [-o <format>] [--non-interactive] <provider> <name>

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

       --non-interactive
              fail instead of prompting for missing values

ENVIRONMENT
       MASTERS
              space-separated list of master node groups (format: type:count[:key=val,key2=val2])

       WORKERS
              space-separated list of worker node groups (format: type:count[:key=val,key2=val2])

       USER_DATA
              optional user-data script

       NETWORK_NAME
              name of the private network (default: private)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _PROVIDER=""
    _NAME=""
    _NON_INTERACTIVE=0
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
            --non-interactive)
                _NON_INTERACTIVE=1
                shift
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
    export PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    export CLUSTER_DIR="$ROCK8S_STATE_HOME/clusters/$_NAME"
    export CLUSTER_NAME="$_NAME"
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    if [ ! -d "$PROVIDER_DIR" ]; then
        _fail "provider $_PROVIDER not found"
    fi
    _CONFIG_FILE="$ROCK8S_CONFIG_PATH/clusters/$_NAME/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        mkdir -p "$(dirname "$_CONFIG_FILE")"
        _PROVIDER_CONFIG="$ROCK8S_LIB_PATH/providers/$_PROVIDER/config.sh"
        if [ -f "$_PROVIDER_CONFIG" ]; then
            _TMP_CONFIG="$(mktemp)"
            sh "$_PROVIDER_CONFIG" > "$_TMP_CONFIG"
            if [ -s "$_TMP_CONFIG" ]; then
                mv "$_TMP_CONFIG" "$_CONFIG_FILE"
            else
                rm -f "$_TMP_CONFIG"
                _fail "failed to generate config file"
            fi
        fi
    fi
    if [ -d "$CLUSTER_DIR" ]; then
        _fail "cluster $_NAME already exists"
    fi
    mkdir -p "$CLUSTER_DIR"
    cp -r "$PROVIDER_DIR" "$CLUSTER_DIR/provider"
    _yaml2json < "$_CONFIG_FILE" > "$CLUSTER_DIR/provider/terraform.tfvars.json"
    if [ -f "$CLUSTER_DIR/provider/variables.sh" ]; then
        . "$CLUSTER_DIR/provider/variables.sh"
    fi
    cd "$CLUSTER_DIR/provider"
    terraform init -backend=true -backend-config="path=$_CLUSTER_DIR/terraform.tfstate" >&2
    terraform apply -auto-approve -state="$_CLUSTER_DIR/terraform.tfstate" >&2
    terraform output -json > "$_CLUSTER_DIR/nodes.json" >&2
    printf '{"name":"%s","provider":"%s","status":"created"}\n' "$_NAME" "$_PROVIDER" | \
        _format_output "$_FORMAT"
}

_main "$@"
