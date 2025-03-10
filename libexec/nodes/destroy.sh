#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes destroy - destroy cluster nodes

SYNOPSIS
       rock8s nodes destroy [-h] [-o <format>] [--cluster <cluster>] [--tenant <tenant>] [--force] [-y|--yes] <purpose>

DESCRIPTION
       destroy cluster nodes for a specific purpose (pfsense, master, or worker)

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
              name of the cluster to destroy nodes for

       --force
              skip dependency checks for destruction order

       -y, --yes
              skip confirmation prompt
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _PURPOSE=""
    _CLUSTER="$ROCK8S_CLUSTER"
    _FORCE=0
    _YES=0
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
            --force)
                _FORCE=1
                shift
                ;;
            -y|--yes)
                _YES=1
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
    if [ -z "$_PURPOSE" ]; then
        _help
        exit 1
    fi
    if ! echo "$_PURPOSE" | grep -qE '^(pfsense|master|worker)$'; then
        _fail "purpose $_PURPOSE not found"
    fi
    _CLUSTER_DIR="$(_get_cluster_dir)"
    _PROVIDER="$(_get_provider)"
    _PURPOSE_DIR="$_CLUSTER_DIR/$_PURPOSE"
    if [ ! -d "$_PURPOSE_DIR" ] || [ ! -f "$_PURPOSE_DIR/output.json" ]; then
        _fail "nodes $_PURPOSE not found"
    fi
    if [ "$_FORCE" != "1" ]; then
        case "$_PURPOSE" in
            pfsense)
                if [ -d "$_CLUSTER_DIR/master" ] || [ -d "$_CLUSTER_DIR/worker" ]; then
                    _fail "nodes master and worker must be destroyed before nodes pfsense"
                fi
                ;;
            master)
                if [ -d "$_CLUSTER_DIR/worker" ]; then
                    _fail "nodes worker must be destroyed before nodes master"
                fi
                ;;
        esac
    fi
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    if [ ! -d "$_PROVIDER_DIR" ]; then
        _fail "provider $_PROVIDER not found"
    fi
    rm -rf "$_CLUSTER_DIR/provider"
    cp -r "$_PROVIDER_DIR" "$_CLUSTER_DIR/provider"
    if [ -d "$_CLUSTER_DIR/provider.terraform" ]; then
        mv "$_CLUSTER_DIR/provider.terraform" "$_CLUSTER_DIR/provider/.terraform"
    fi
    echo "$(_get_config_json)" | sh "$_CLUSTER_DIR/provider/tfvars.sh" "$_PURPOSE" > "$_PURPOSE_DIR/terraform.tfvars.json"
    if [ "$_PURPOSE" != "pfsense" ]; then
        export TF_VAR_user_data="$(_get_cloud_init_config "$_PURPOSE_DIR/id_rsa.pub")"
    fi
    export TF_VAR_cluster_name="$_CLUSTER"
    export TF_VAR_purpose="$_PURPOSE"
    export TF_VAR_ssh_public_key_path="$_PURPOSE_DIR/id_rsa.pub"
    export TF_VAR_cluster_dir="$_CLUSTER_DIR"
    export TF_VAR_tenant="$_TENANT"
    export TF_DATA_DIR="$_PURPOSE_DIR/.terraform"
    if [ -f "$_CLUSTER_DIR/provider/variables.sh" ]; then
        . "$_CLUSTER_DIR/provider/variables.sh"
    fi
    cd "$_CLUSTER_DIR/provider"
    if [ ! -f "$TF_DATA_DIR/terraform.tfstate" ] || \
        [ ! -f "$_PROVIDER_DIR/.terraform.lock.hcl" ] || \
        [ ! -d "$TF_DATA_DIR/providers" ] || \
        [ "$_PROVIDER_DIR/.terraform.lock.hcl" -nt "$TF_DATA_DIR/terraform.tfstate" ] || \
        (find "$_PROVIDER_DIR" -type f -name "*.tf" -newer "$TF_DATA_DIR/terraform.tfstate" 2>/dev/null | grep -q .); then
        terraform init -upgrade -backend=true -backend-config="path=$_PURPOSE_DIR/terraform.tfstate" >&2
        touch -m "$TF_DATA_DIR/terraform.tfstate"
    fi
    terraform destroy $([ "$_YES" = "1" ] && echo "-auto-approve" || true) -var-file="$_PURPOSE_DIR/terraform.tfvars.json" >&2
    rm -rf "$_PURPOSE_DIR"
    if [ ! -d "$_CLUSTER_DIR/worker" ] && [ ! -d "$_CLUSTER_DIR/master" ]; then
        rm -rf "$_CLUSTER_DIR/provider"
    fi
    if [ -z "$(ls -A "$_CLUSTER_DIR")" ]; then
        rm -rf "$_CLUSTER_DIR"
    fi
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","purpose":"%s"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" "$_PURPOSE" | \
        _format_output "$_FORMAT"
}

_main "$@"
