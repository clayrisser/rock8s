#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s nodes create - create cluster nodes

SYNOPSIS
       rock8s nodes create [-h] [-o <format>] [--non-interactive] [--tenant <tenant>] <provider> <name>

DESCRIPTION
       create cluster nodes

ARGUMENTS
       provider
              name of the provider source to use

       name
              name of the node group to create

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

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
    _TENANT="$ROCK8S_TENANT"
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
            -t|--tenant|-t=*|--tenant=*)
                case "$1" in
                    *=*)
                        _TENANT="${1#*=}"
                        shift
                        ;;
                    *)
                        _TENANT="$2"
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
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    export CLUSTER_DIR="$ROCK8S_STATE_ROOT/$_TENANT/clusters/$_NAME"
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    if [ ! -d "$_PROVIDER_DIR" ]; then
        _fail "provider $_PROVIDER not found"
    fi
    _CONFIG_FILE="$ROCK8S_CONFIG_HOME/tenants/$_TENANT/clusters/$_NAME/config.yaml"
    if [ -f "$_PROVIDER_DIR/config.sh" ] && [ ! -f "$_CONFIG_FILE" ] && [ "$_NON_INTERACTIVE" = "0" ]; then
        mkdir -p "$(dirname "$_CONFIG_FILE")"
        { _ERROR="$(sh "$_PROVIDER_DIR/config.sh" "$_CONFIG_FILE")"; _EXIT_CODE="$?"; } || true
        if [ "$_EXIT_CODE" -ne 0 ]; then
            if [ -n "$_ERROR" ]; then
                _fail "$_ERROR"
            else
                _fail "provider config script failed"
            fi
        fi
        if [ ! -f "$_CONFIG_FILE" ]; then
            _fail "provider config script failed to create config file"
        fi
    fi
    if [ -d "$CLUSTER_DIR" ]; then
        _fail "cluster $_NAME already exists"
    fi
    mkdir -p "$CLUSTER_DIR"
    cp -r "$_PROVIDER_DIR" "$CLUSTER_DIR/provider"
    _yaml2json < "$_CONFIG_FILE" > "$CLUSTER_DIR/provider/terraform.tfvars.json"
    if [ -f "$CLUSTER_DIR/provider/variables.sh" ]; then
        . "$CLUSTER_DIR/provider/variables.sh"
    fi
    cd "$CLUSTER_DIR/provider"
    echo terraform init -backend=true -backend-config="path=$CLUSTER_DIR/provider/terraform.tfstate" >&2
    echo terraform apply -auto-approve -state="$CLUSTER_DIR/provider/terraform.tfstate" >&2
    echo terraform output -json > "$CLUSTER_DIR/provider/output.json" >&2
    printf '{"name":"%s","provider":"%s","tenant":"%s"}\n' "$_NAME" "$_PROVIDER" "$_TENANT" | \
        _format_output "$_FORMAT"
}

_main "$@"
