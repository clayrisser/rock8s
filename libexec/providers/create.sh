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

    [ -z "$_PROVIDER" ] && {
        _fail "provider name required"
    }
    [ -z "$_NAME" ] && {
        _fail "cluster name required"
    }

    _validate_cluster_name "$_NAME"
    _PROVIDER_DIR="$ROCK8S_PROVIDERS_PATH/$_PROVIDER"
    _CLUSTER_DIR="$(_get_cluster_dir "$_NAME")"
    _TF_DIR="$_CLUSTER_DIR/terraform/$_PROVIDER"

    [ -d "$_PROVIDER_DIR" ] || {
        _fail "provider '$_PROVIDER' not found"
    }

    _ensure_terraform
    mkdir -p "$_TF_DIR"

    # Copy provider Terraform files
    cp -r "$_PROVIDER_DIR"/* "$_TF_DIR/"

    # Create terraform.tfvars if it doesn't exist
    [ ! -f "$_TF_DIR/terraform.tfvars" ] && {
        cp "$_TF_DIR/terraform.tfvars.example" "$_TF_DIR/terraform.tfvars" 2>/dev/null || true
    }

    cd "$_TF_DIR"
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan

    # Save node information
    terraform output -json > "$_CLUSTER_DIR/nodes.json"

    printf '{"name":"%s","provider":"%s","status":"created"}\n' "$_NAME" "$_PROVIDER" | \
        _format_output "$_FORMAT" providers
}

_main "$@"
