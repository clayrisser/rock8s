#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes apply - create or update cluster nodes

SYNOPSIS
       rock8s nodes apply [-h] [-o <format>] [--non-interactive] [--cluster <cluster>] [--tenant <tenant>] [--force] <purpose>

DESCRIPTION
       create new cluster nodes or update existing ones for a specific purpose (pfsense, master, or worker)

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
              name of the cluster to create/update nodes for (required)

       --force
              skip dependency checks for creation order

       --non-interactive
              fail instead of prompting for missing values

       -y, --yes
              skip confirmation prompt
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _PURPOSE=""
    _CLUSTER="$ROCK8S_CLUSTER"
    _NON_INTERACTIVE=0
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
            --non-interactive)
                _NON_INTERACTIVE=1
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
    if [ -z "$_PURPOSE" ] || [ -z "$_CLUSTER" ]; then
        _help
        exit 1
    fi
    if ! echo "$_PURPOSE" | grep -qE '^(pfsense|master|worker)$'; then
        _fail "$_PURPOSE is invalid"
    fi
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    _CLUSTER_DIR="$(_get_cluster_dir)"
    _PROVIDER="$(_get_provider)"
    _PURPOSE_DIR="$_CLUSTER_DIR/$_PURPOSE"
    _IS_UPDATE=0
    if [ -d "$_PURPOSE_DIR" ] && [ -f "$_PURPOSE_DIR/output.json" ]; then
        _IS_UPDATE=1
    fi
    if [ "$_IS_UPDATE" != "1" ]; then
        if [ "$_FORCE" != "1" ]; then
            case "$_PURPOSE" in
                master)
                    if [ ! -d "$_CLUSTER_DIR/pfsense" ]; then
                        _fail "pfsense nodes must be created before master nodes"
                    fi
                    ;;
                worker)
                    if [ ! -d "$_CLUSTER_DIR/pfsense" ]; then
                        _fail "pfsense nodes must be created before worker nodes"
                    fi
                    if [ ! -d "$_CLUSTER_DIR/master" ]; then
                        _fail "master nodes must be created before worker nodes"
                    fi
                    ;;
            esac
        fi
        mkdir -p "$_PURPOSE_DIR"
        if [ ! -f "$_PURPOSE_DIR/id_rsa" ]; then
            ssh-keygen -t rsa -b 4096 -f "$_PURPOSE_DIR/id_rsa" -N "" -C "rock8s-$_CLUSTER-$_PURPOSE"
        fi
        chmod 600 "$_PURPOSE_DIR/id_rsa"
        chmod 644 "$_PURPOSE_DIR/id_rsa.pub"
    fi
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    if [ ! -d "$_PROVIDER_DIR" ]; then
        _fail "provider $_PROVIDER not found"
    fi
    rm -rf "$_CLUSTER_DIR/provider"
    cp -r "$_PROVIDER_DIR" "$_CLUSTER_DIR/provider"
    _get_config_json | sh "$_CLUSTER_DIR/provider/tfvars.sh" "$_PURPOSE" > "$_PURPOSE_DIR/terraform.tfvars.json"
    chmod 600 "$_PURPOSE_DIR/terraform.tfvars.json"
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
    terraform apply $([ "$_YES" = "1" ] && echo "-auto-approve" || true) -var-file="$_PURPOSE_DIR/terraform.tfvars.json" >&2
    terraform output -json > "$_PURPOSE_DIR/output.json"
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","purpose":"%s"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" "$_PURPOSE" | \
        _format_output "$_FORMAT"
}

_main "$@"
