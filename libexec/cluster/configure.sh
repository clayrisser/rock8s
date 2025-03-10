#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster configure - configure a kubernetes cluster

SYNOPSIS
       rock8s cluster configure [-h] [-o <format>] [-y|--yes] [-t <tenant>] --cluster <cluster> [--kubeconfig <path>]

DESCRIPTION
       configure a kubernetes cluster with the necessary infrastructure

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to configure (required)

       --kubeconfig <path>
              path to the kubeconfig file

       -y, --yes
              automatically approve operations without prompting
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _YES=0
    _TENANT="$ROCK8S_TENANT"
    _KUBECONFIG=""
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
            -y|--yes)
                _YES=1
                shift
                ;;
            --non-interactive)
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
            --kubeconfig|--kubeconfig=*)
                case "$1" in
                    *=*)
                        _KUBECONFIG="${1#*=}"
                        shift
                        ;;
                    *)
                        _KUBECONFIG="$2"
                        shift 2
                        ;;
                esac
                ;;
            -*)
                _help
                exit 1
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    if [ -z "$_CLUSTER" ]; then
        _fail "cluster name required (use --cluster)"
    fi
    _ensure_system
    
    _CLUSTER_DIR="$(_get_cluster_dir "$_TENANT" "$_CLUSTER")"
    _validate_cluster_dir "$_CLUSTER_DIR"
    
    _CONFIG_FILE="$(_get_cluster_config_file "$_TENANT" "$_CLUSTER")"
    _validate_cluster_config "$_CONFIG_FILE"
    
    _CONFIG_JSON="$(yaml2json < "$_CONFIG_FILE")"
    _PROVIDER="$(_get_cluster_provider "$_CONFIG_JSON")"
    _ENTRYPOINT="$(_get_cluster_entrypoint "$_CONFIG_JSON")"
    
    _validate_cluster_node "$_CLUSTER_DIR" "pfsense"
    _validate_cluster_node "$_CLUSTER_DIR" "master"
    
    _KUBECONFIG="$(_get_cluster_kubeconfig "$_CLUSTER_DIR" "$_KUBECONFIG")"
    _ADDONS_DIR="$(_get_cluster_addons_dir "$_CLUSTER_DIR")"
    
    mkdir -p "$_ADDONS_DIR"
    rm -rf "$_ADDONS_DIR/terraform"
    cp -r "$ROCK8S_LIB_PATH/addons" "$_ADDONS_DIR/terraform"
    echo "$_CONFIG_JSON" | jq -e '.addons // {}' > $_ADDONS_DIR/terraform.tfvars.json
    
    export TF_VAR_cluster_name="$_CLUSTER"
    export TF_VAR_entrypoint="$_ENTRYPOINT"
    export TF_VAR_kubeconfig="$_KUBECONFIG"
    export TF_DATA_DIR="$_ADDONS_DIR/.terraform"
    
    cd "$_ADDONS_DIR/terraform"
    if [ ! -f "$TF_DATA_DIR/terraform.tfstate" ] || \
        [ ! -f "$ROCK8S_LIB_PATH/addons/.terraform.lock.hcl" ] || \
        [ ! -d "$TF_DATA_DIR/providers" ] || \
        [ "$ROCK8S_LIB_PATH/addons/.terraform.lock.hcl" -nt "$TF_DATA_DIR/terraform.tfstate" ] || \
        (find "$ROCK8S_LIB_PATH/addons" -type f -name "*.tf" -newer "$TF_DATA_DIR/terraform.tfstate" 2>/dev/null | grep -q .); then
        terraform init -upgrade -backend=true -backend-config="path=$_ADDONS_DIR/terraform.tfstate" >&2
        touch -m "$TF_DATA_DIR/terraform.tfstate"
    fi
    terraform apply $([ "$_YES" = "1" ] && echo "-auto-approve") -var-file="$_ADDONS_DIR/terraform.tfvars.json" >&2
    echo terraform output -json > "$_ADDONS_DIR/output.json"
    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" | \
        _format_output "$_FORMAT"
}

_main "$@"
