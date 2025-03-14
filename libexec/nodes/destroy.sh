#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes destroy

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
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

       --force
              skip dependency checks

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # destroy worker nodes
       rock8s nodes destroy --cluster mycluster worker

       # destroy master nodes
       rock8s nodes destroy --cluster mycluster master

       # force destroy pfsense nodes without confirmation
       rock8s nodes destroy --cluster mycluster --force --yes pfsense

SEE ALSO
       rock8s nodes apply --help
       rock8s nodes ls --help
       rock8s nodes ssh --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
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
                        _OUTPUT="${1#*=}"
                        shift
                        ;;
                    *)
                        _OUTPUT="$2"
                        shift 2
                        ;;
                esac
                ;;
            -c|--cluster|-c=*|--cluster=*)
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
        fail "purpose $_PURPOSE not found"
    fi
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    _CLUSTER_DIR="$(get_cluster_dir)"
    _PROVIDER="$(get_provider)"
    _PURPOSE_DIR="$_CLUSTER_DIR/$_PURPOSE"
    if [ ! -d "$_PURPOSE_DIR" ] || [ ! -f "$_PURPOSE_DIR/output.json" ]; then
        fail "nodes $_PURPOSE not found"
    fi
    if [ "$_FORCE" != "1" ]; then
        case "$_PURPOSE" in
            pfsense)
                if [ -d "$_CLUSTER_DIR/master" ] || [ -d "$_CLUSTER_DIR/worker" ]; then
                    fail "nodes master and worker must be destroyed before nodes pfsense"
                fi
                ;;
            master)
                if [ -d "$_CLUSTER_DIR/worker" ]; then
                    fail "nodes worker must be destroyed before nodes master"
                fi
                ;;
        esac
    fi
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    if [ ! -d "$_PROVIDER_DIR" ]; then
        fail "provider $_PROVIDER not found"
    fi
    rm -rf "$_CLUSTER_DIR/provider"
    cp -r "$_PROVIDER_DIR" "$_CLUSTER_DIR/provider"
    if [ -d "$_CLUSTER_DIR/provider.terraform" ]; then
        mv "$_CLUSTER_DIR/provider.terraform" "$_CLUSTER_DIR/provider/.terraform"
    fi
    export TF_VAR_cluster_name="$_CLUSTER"
    export TF_VAR_purpose="$_PURPOSE"
    export TF_VAR_ssh_public_key_path="$_PURPOSE_DIR/id_rsa.pub"
    export TF_VAR_cluster_dir="$_CLUSTER_DIR"
    export TF_VAR_tenant="$_TENANT"
    export TF_DATA_DIR="$_PURPOSE_DIR/.terraform"
    _CONFIG_JSON="$(get_config_json)"
    echo "$_CONFIG_JSON" | . "$_CLUSTER_DIR/provider/tfvars.sh" > "$_PURPOSE_DIR/terraform.tfvars.json"
    chmod 600 "$_PURPOSE_DIR/terraform.tfvars.json"
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
        format_output "$_OUTPUT"
}

_main "$@"
