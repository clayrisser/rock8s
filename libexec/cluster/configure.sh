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
    _CONFIG_FILE="$ROCK8S_CONFIG_HOME/tenants/$_TENANT/clusters/$_CLUSTER/config.yaml"
    _PROVIDER="$([ -f "$_CONFIG_FILE" ] && (yaml2json < "$_CONFIG_FILE" | jq -r '.provider') || true)"
    if [ -z "$_PROVIDER" ] || [ "$_PROVIDER" = "null" ]; then
        _fail "provider not specified in config.yaml"
    fi
    if [ ! -f "$_CONFIG_FILE" ]; then
        _fail "cluster configuration file not found at $_CONFIG_FILE"
    fi
    export CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$_TENANT/clusters/$_CLUSTER"
    if [ ! -d "$CLUSTER_DIR" ]; then
        _fail "cluster state directory not found at $CLUSTER_DIR"
    fi
    if [ ! -d "$CLUSTER_DIR/pfsense" ] || [ ! -d "$CLUSTER_DIR/master" ]; then
        _fail "pfsense and master nodes must be created before configuring the cluster"
    fi
    if [ -n "$_KUBECONFIG" ]; then
        if [ ! -f "$_KUBECONFIG" ]; then
            _fail "kubeconfig not found"
        fi
    else
        if [ ! -f "$CLUSTER_DIR/kube.yaml" ]; then
            _fail "kubeconfig not found"
        fi
        _KUBECONFIG="$CLUSTER_DIR/kube.yaml"
    fi
    _CONFIG_JSON=$(yaml2json < "$_CONFIG_FILE")
    _ENTRYPOINT=$(echo "$_CONFIG_JSON" | jq -r '.network.entrypoint // ""')
    if [ -z "$_ENTRYPOINT" ] || [ "$_ENTRYPOINT" = "null" ]; then
        _fail ".network.entrypoint not specified in config.yaml"
    fi
    _ADDONS_DIR="$CLUSTER_DIR/addons"
    mkdir -p "$_ADDONS_DIR"
    rm -rf "$_ADDONS_DIR/terraform"
    cp -r "$ROCK8S_LIB_PATH/addons" "$_ADDONS_DIR/terraform"
    echo "$_CONFIG_JSON" | jq -e '.cluster // {}' > $_ADDONS_DIR/terraform.tfvars.json
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
        terraform init -backend=true -backend-config="path=$_ADDONS_DIR/terraform.tfstate" >&2
        touch -m "$TF_DATA_DIR/terraform.tfstate"
    fi
    terraform apply $([ "$_YES" = "1" ] && echo "-auto-approve") -var-file="$_ADDONS_DIR/terraform.tfvars.json" >&2
    terraform output -json > "$_ADDONS_DIR/output.json"
    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" | \
        _format_output "$_FORMAT"
}

_main "$@"
