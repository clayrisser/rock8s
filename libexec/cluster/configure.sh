#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster configure - configure a kubernetes cluster

SYNOPSIS
       rock8s cluster configure [-h] [-o <format>] [-y|--yes] [-t <tenant>] [--non-interactive] --cluster <cluster> [--kubeconfig <path>] [--update] [--pfsense-password <password>] [--pfsense-ssh-password] [--skip-kubespray]

DESCRIPTION
       configure a kubernetes cluster with the necessary infrastructure

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

       --non-interactive
              fail instead of prompting

       --update
              update ansible collections

       --pfsense-password <password>
              admin password

       --pfsense-ssh-password
              use password authentication for ssh

       --skip-kubespray
              skip kubespray installation steps

EXAMPLE
       # configure a cluster with automatic approval
       rock8s cluster configure --cluster mycluster --yes

       # configure a cluster with a specific tenant and password
       rock8s cluster configure --cluster mycluster --tenant mytenant --pfsense-password mypassword

SEE ALSO
       rock8s cluster install --help
       rock8s cluster upgrade --help
       rock8s pfsense configure --help
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _YES=0
    _TENANT="$ROCK8S_TENANT"
    _KUBECONFIG=""
    _NON_INTERACTIVE=""
    _UPDATE=""
    _PFSENSE_PASSWORD=""
    _PFSENSE_SSH_PASSWORD=""
    _SKIP_KUBESPRAY=""
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
                _NON_INTERACTIVE="1"
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
            --update)
                _UPDATE="1"
                shift
                ;;
            --pfsense-password|--pfsense-password=*)
                case "$1" in
                    *=*)
                        _PFSENSE_PASSWORD="${1#*=}"
                        shift
                        ;;
                    *)
                        _PFSENSE_PASSWORD="$2"
                        shift 2
                        ;;
                esac
                ;;
            --pfsense-ssh-password|--pfsense-ssh-password=*)
                case "$1" in
                    *=*)
                        _PFSENSE_SSH_PASSWORD="${1#*=}"
                        shift
                        ;;
                    *)
                        _PFSENSE_SSH_PASSWORD="$2"
                        shift 2
                        ;;
                esac
                ;;
            --skip-kubespray)
                _SKIP_KUBESPRAY="1"
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
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    _CLUSTER_DIR="$(get_cluster_dir)"
    _ADDONS_DIR="$_CLUSTER_DIR/addons"
    if [ -z "$_SKIP_KUBESPRAY" ]; then
        if [ ! -f "$_CLUSTER_DIR/kube.yaml" ]; then
            sh "$ROCK8S_LIB_PATH/libexec/cluster/install.sh" \
                --output="$_FORMAT" \
                --cluster="$_CLUSTER" \
                --tenant="$_TENANT" \
                $([ "$_YES" = "1" ] && echo "--yes") \
                $([ "$_NON_INTERACTIVE" = "1" ] && echo "--non-interactive") \
                $([ "$_UPDATE" = "1" ] && echo "--update") \
                $([ -n "$_PFSENSE_PASSWORD" ] && echo "--pfsense-password=$_PFSENSE_PASSWORD") \
                $([ -n "$_PFSENSE_SSH_PASSWORD" ] && echo "--pfsense-ssh-password=$_PFSENSE_SSH_PASSWORD")
        else
            sh "$ROCK8S_LIB_PATH/libexec/cluster/upgrade.sh" \
                --output="$_FORMAT" \
                --cluster="$_CLUSTER" \
                --tenant="$_TENANT" \
                $([ "$_YES" = "1" ] && echo "--yes") \
                $([ "$_NON_INTERACTIVE" = "1" ] && echo "--non-interactive") \
                $([ "$_UPDATE" = "1" ] && echo "--update") \
                $([ -n "$_PFSENSE_PASSWORD" ] && echo "--pfsense-password=$_PFSENSE_PASSWORD") \
                $([ -n "$_PFSENSE_SSH_PASSWORD" ] && echo "--pfsense-ssh-password=$_PFSENSE_SSH_PASSWORD")
        fi
    fi
    mkdir -p "$_ADDONS_DIR"
    rm -rf "$_ADDONS_DIR/terraform"
    cp -r "$ROCK8S_LIB_PATH/addons" "$_ADDONS_DIR/terraform"
    export TF_VAR_cluster_name="$_CLUSTER"
    export TF_VAR_entrypoint="$(get_entrypoint)"
    export TF_VAR_kubeconfig="$_CLUSTER_DIR/kube.yaml"
    export TF_DATA_DIR="$_ADDONS_DIR/.terraform"
    export TF_VAR_ingress_nginx_load_balancer="$([ "$(get_external_network)" = "1" ] && echo "0" || echo "1")"
    _CONFIG_JSON="$(get_config_json)"
    echo "$_CONFIG_JSON" | jq -r '.addons * {registries: .registries}' > "$_ADDONS_DIR/terraform.tfvars.json"
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
        format_output "$_FORMAT"
}

_main "$@"
