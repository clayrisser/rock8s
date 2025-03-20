#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster addons

SYNOPSIS
       rock8s cluster addons [-h] [-o <format>] [-y|--yes] [-t <tenant>] [--cluster <cluster>] [--kubeconfig <path>] [--update]

DESCRIPTION
       configure cluster addons for an existing kubernetes cluster

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

       --kubeconfig <path>
              path to kubeconfig

       -y, --yes
              automatically approve operations

       --update
              update ansible collections

EXAMPLE
       # configure addons for a cluster with automatic approval
       rock8s cluster addons --cluster mycluster --yes

       # configure addons for a cluster with a custom kubeconfig
       rock8s cluster addons --cluster mycluster --kubeconfig /path/to/kubeconfig

SEE ALSO
       rock8s cluster apply --help
       rock8s cluster install --help
       rock8s cluster upgrade --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _YES="0"
    _UPDATE=""
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
                        _OUTPUT="${1#*=}"
                        shift
                        ;;
                    *)
                        _OUTPUT="$2"
                        shift 2
                        ;;
                esac
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
            -y|--yes)
                _YES="1"
                shift
                ;;
            --update)
                _UPDATE="1"
                shift
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
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    _CLUSTER_DIR="$(get_cluster_dir)"
    _ADDONS_DIR="$_CLUSTER_DIR/addons"
    mkdir -p "$_ADDONS_DIR"
    rm -rf "$_ADDONS_DIR/terraform"
    cp -r "$ROCK8S_LIB_PATH/addons" "$_ADDONS_DIR/terraform"
    export TF_VAR_cluster_name="$_CLUSTER"
    export TF_VAR_entrypoint="$(get_entrypoint)"
    export TF_VAR_kubeconfig="$_CLUSTER_DIR/kube.yaml"
    export TF_DATA_DIR="$_ADDONS_DIR/.terraform"
    _LOAD_BALANCER_ENABLED="$([ "$(get_external_network)" = "1" ] && echo "0" || echo "1")"
    export TF_VAR_ingress_nginx="{\"load_balancer\":$_LOAD_BALANCER_ENABLED}"
    _CONFIG_JSON="$(get_config_json)"
    _CONFIG_JSON=$(echo "$_CONFIG_JSON" | jq --arg lb "$_LOAD_BALANCER_ENABLED" '.addons.ingress_nginx = {"load_balancer": ($lb == "1")}')
    echo "$_CONFIG_JSON" | jq -r '.addons' > "$_ADDONS_DIR/terraform.tfvars.json"
    chmod 600 "$_ADDONS_DIR/terraform.tfvars.json"
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
    terraform output -json > "$_ADDONS_DIR/output.json"
    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$(get_provider)" "$_TENANT" | \
        format_output "$_OUTPUT"
}

_main "$@"
