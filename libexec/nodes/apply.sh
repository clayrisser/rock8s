#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes apply

SYNOPSIS
       rock8s nodes apply [-h] [-o <format>] [--cluster <cluster>] [--tenant <tenant>] [--force] <purpose>

DESCRIPTION
       create new cluster nodes or update existing ones for a specific purpose (pfsense, master, or worker)

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
       # create pfsense nodes
       rock8s nodes apply --cluster mycluster pfsense

       # create master nodes
       rock8s nodes apply --cluster mycluster master

       # create worker nodes
       rock8s nodes apply --cluster mycluster worker

       # update existing nodes with automatic approval
       rock8s nodes apply --cluster mycluster --yes worker

SEE ALSO
       rock8s nodes destroy --help
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
        fail "$_PURPOSE is invalid"
    fi
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    _CLUSTER_DIR="$(get_cluster_dir)"
    _PROVIDER="$(get_provider)"
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
                        fail "pfsense nodes must be created before master nodes"
                    fi
                    ;;
                worker)
                    if [ ! -d "$_CLUSTER_DIR/pfsense" ]; then
                        fail "pfsense nodes must be created before worker nodes"
                    fi
                    if [ ! -d "$_CLUSTER_DIR/master" ]; then
                        fail "master nodes must be created before worker nodes"
                    fi
                    ;;
            esac
        fi
        mkdir -p "$_PURPOSE_DIR"
        if [ ! -f "$_PURPOSE_DIR/id_rsa" ]; then
            ssh-keygen -t rsa -b 4096 -f "$_PURPOSE_DIR/id_rsa" -N "" -C "rock8s-$_CLUSTER-$_PURPOSE" >&2
        fi
        chmod 600 "$_PURPOSE_DIR/id_rsa"
        chmod 644 "$_PURPOSE_DIR/id_rsa.pub"
    fi
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    if [ ! -d "$_PROVIDER_DIR" ]; then
        fail "provider $_PROVIDER not found"
    fi
    rm -rf "$_CLUSTER_DIR/provider"
    cp -r "$_PROVIDER_DIR" "$_CLUSTER_DIR/provider"
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
    terraform apply $([ "$_YES" = "1" ] && echo "-auto-approve" || true) -var-file="$_PURPOSE_DIR/terraform.tfvars.json" >&2
    terraform output -json > "$_PURPOSE_DIR/output.json"
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","purpose":"%s"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" "$_PURPOSE" | \
        format_output "$_OUTPUT"
}

_main "$@"
