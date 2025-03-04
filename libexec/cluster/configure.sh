#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster configure - configure a kubernetes cluster

SYNOPSIS
       rock8s cluster configure [-h] [-o <format>] [--non-interactive] [--tenant <tenant>] --cluster <cluster>

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

       --non-interactive
              fail instead of prompting for missing values
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
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
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
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

    # Check if required nodes exist
    if [ ! -d "$CLUSTER_DIR/pfsense" ] || [ ! -d "$CLUSTER_DIR/master" ]; then
        _fail "pfsense and master nodes must be created before configuring the cluster"
    fi

    # Create cluster configuration directory if it doesn't exist
    export _CONFIG_DIR="$CLUSTER_DIR/config"
    mkdir -p "$_CONFIG_DIR"

    # Get kubeconfig path
    _KUBECONFIG="$CLUSTER_DIR/auth/kubeconfig"
    if [ ! -f "$_KUBECONFIG" ]; then
        _fail "kubeconfig not found at $_KUBECONFIG"
    fi

    # Generate terraform variables file from config.yaml
    _CONFIG_JSON=$(yaml2json < "$_CONFIG_FILE")

    # Extract required variables from config
    _EMAIL=$(echo "$_CONFIG_JSON" | jq -r '.email // ""')
    if [ -z "$_EMAIL" ] || [ "$_EMAIL" = "null" ]; then
        _fail "email not specified in config.yaml"
    fi
    _ENTRYPOINT=$(echo "$_CONFIG_JSON" | jq -r '.network.entrypoint // ""')
    if [ -z "$_ENTRYPOINT" ] || [ "$_ENTRYPOINT" = "null" ]; then
        _fail ".network.entrypoint not specified in config.yaml"
    fi

    # Create terraform.tfvars.json with all variables
    # Start with required variables
    echo "{
  \"cluster_name\": \"$_CLUSTER\",
  \"email\": \"$_EMAIL\",
  \"entrypoint\": \"$_ENTRYPOINT\",
  \"kubeconfig\": \"$_KUBECONFIG\"" > "$_CONFIG_DIR/terraform.tfvars.json"

    # Process cluster section if it exists and add all variables from it
    if echo "$_CONFIG_JSON" | jq -e '.cluster' > /dev/null 2>&1; then
        echo "$_CONFIG_JSON" | jq -r '.cluster | to_entries[] | ",\n  \"\(.key)\": \(.value)"' >> "$_CONFIG_DIR/terraform.tfvars.json"
    fi

    # Close the JSON object
    echo "
}" >> "$_CONFIG_DIR/terraform.tfvars.json"

    # Set up Terraform environment variables
    export TF_VAR_cluster_name="$_CLUSTER"
    export TF_VAR_email="$_EMAIL"
    export TF_VAR_entrypoint="$_ENTRYPOINT"
    export TF_VAR_kubeconfig="$_KUBECONFIG"
    export TF_DATA_DIR="$_CONFIG_DIR/.terraform"

    # Copy Kubernetes cluster Terraform files if needed
    if [ ! -d "$_CONFIG_DIR/terraform" ]; then
        mkdir -p "$_CONFIG_DIR/terraform"
        cp -r "$ROCK8S_LIB_PATH/kubernetes/cluster"/*.tf "$_CONFIG_DIR/terraform/"
        cp -r "$ROCK8S_LIB_PATH/kubernetes/cluster/modules" "$_CONFIG_DIR/terraform/"
    fi

    # Initialize and apply Terraform
    cd "$_CONFIG_DIR/terraform"
    if [ ! -f "$TF_DATA_DIR/terraform.tfstate" ] || \
        [ ! -f "$ROCK8S_LIB_PATH/kubernetes/cluster/.terraform.lock.hcl" ] || \
        [ ! -d "$TF_DATA_DIR/providers" ] || \
        [ "$ROCK8S_LIB_PATH/kubernetes/cluster/.terraform.lock.hcl" -nt "$TF_DATA_DIR/terraform.tfstate" ] || \
        (find "$ROCK8S_LIB_PATH/kubernetes/cluster" -type f -name "*.tf" -newer "$TF_DATA_DIR/terraform.tfstate" 2>/dev/null | grep -q .); then
        terraform init -backend=true -backend-config="path=$_CONFIG_DIR/terraform.tfstate" >&2
        touch -m "$TF_DATA_DIR/terraform.tfstate"
    fi
    terraform apply $([ "$NON_INTERACTIVE" = "1" ] && echo "-auto-approve") -state="$_CONFIG_DIR/terraform.tfstate" -var-file="$_CONFIG_DIR/terraform.tfvars.json" >&2
    terraform output -state="$_CONFIG_DIR/terraform.tfstate" -json > "$_CONFIG_DIR/output.json"

    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" | \
        _format_output "$_FORMAT"
}

_main "$@"
