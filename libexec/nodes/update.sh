#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes update - update cluster nodes

SYNOPSIS
       rock8s nodes update [-h] [-o <format>] [--non-interactive] [--cluster <cluster>] [--tenant <tenant>] <purpose>

DESCRIPTION
       update existing cluster nodes by reapplying terraform configuration

ARGUMENTS
       purpose
              purpose of the nodes (pfsense, master, or worker)

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to update nodes for (required)

       --non-interactive
              fail instead of prompting for missing values
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _PURPOSE=""
    _CLUSTER=""
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
            --cluster|--cluster=*)
                case "$1" in
                    *=*)
                        _CLUSTER="${1#*=}"
                        shift
                        ;;
                    *)
                        _CLUSTER="$2"
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
                if [ -z "$_PURPOSE" ]; then
                    _PURPOSE="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done
    if [ -z "$_PURPOSE" ] || [ -z "$_CLUSTER" ]; then
        _help
        exit 1
    fi
    if ! echo "$_PURPOSE" | grep -qE '^(pfsense|master|worker)$'; then
        _fail "$_PURPOSE is invalid"
    fi
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    _ensure_system
    _CONFIG_FILE="$ROCK8S_CONFIG_HOME/tenants/$_TENANT/clusters/$_CLUSTER/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        _fail "cluster configuration file not found at $_CONFIG_FILE"
    fi
    _PROVIDER="$(_yaml2json < "$_CONFIG_FILE" | jq -r '.provider')"
    if [ -z "$_PROVIDER" ] || [ "$_PROVIDER" = "null" ]; then
        _fail "provider not specified in config.yaml"
    fi
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    if [ ! -d "$_PROVIDER_DIR" ]; then
        _fail "provider $_PROVIDER not found"
    fi
    export CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$_TENANT/clusters/$_CLUSTER"
    if [ ! -d "$CLUSTER_DIR" ]; then
        _fail "cluster $_CLUSTER not found"
    fi
    export _PURPOSE_DIR="$CLUSTER_DIR/$_PURPOSE"
    if [ ! -d "$_PURPOSE_DIR" ] || [ ! -f "$_PURPOSE_DIR/output.json" ]; then
        _fail "cluster nodes for $_PURPOSE not found"
    fi
    rm -rf "$CLUSTER_DIR/provider"
    cp -r "$_PROVIDER_DIR" "$CLUSTER_DIR/provider"
    case "$_PURPOSE" in
        pfsense)
            _yaml2json < "$_CONFIG_FILE" | jq '. + {nodes: .pfsense} | del(.pfsense, .masters, .workers, .provider)' > "$_PURPOSE_DIR/terraform.tfvars.json"
            ;;
        master)
            _yaml2json < "$_CONFIG_FILE" | jq '. + {nodes: .masters} | del(.pfsense, .masters, .workers, .provider)' > "$_PURPOSE_DIR/terraform.tfvars.json"
            ;;
        worker)
            _yaml2json < "$_CONFIG_FILE" | jq '. + {nodes: .workers} | del(.pfsense, .masters, .workers, .provider)' > "$_PURPOSE_DIR/terraform.tfvars.json"
            ;;
    esac
    if [ "$_PURPOSE" != "pfsense" ]; then
        export TF_VAR_user_data="$(_get_cloud_init_config "$_PURPOSE_DIR/id_rsa.pub")"
    fi
    export TF_VAR_cluster_name="$_CLUSTER"
    export TF_VAR_purpose="$_PURPOSE"
    export TF_VAR_ssh_public_key_path="$_PURPOSE_DIR/id_rsa.pub"
    export TF_VAR_cluster_dir="$CLUSTER_DIR"
    export TF_VAR_tenant="$_TENANT"
    if [ -f "$CLUSTER_DIR/provider/variables.sh" ]; then
        . "$CLUSTER_DIR/provider/variables.sh"
    fi
    cd "$CLUSTER_DIR/provider"
    terraform init -backend=true -backend-config="path=$_PURPOSE_DIR/terraform.tfstate" >&2
    terraform apply $([ "$NON_INTERACTIVE" = "1" ] && echo "-auto-approve" || true) -state="$_PURPOSE_DIR/terraform.tfstate" -var-file="$_PURPOSE_DIR/terraform.tfvars.json" >&2
    terraform output -state="$_PURPOSE_DIR/terraform.tfstate" -json > "$_PURPOSE_DIR/output.json"
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","purpose":"%s","status":"updated"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" "$_PURPOSE" | \
        _format_output "$_FORMAT"
}

_main "$@"
