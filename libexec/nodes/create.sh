#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s nodes create - create cluster nodes

SYNOPSIS
       rock8s nodes create [-h] [-o <format>] [--non-interactive] [--tenant <tenant>] <provider> <cluster>

DESCRIPTION
       create cluster nodes for pfsense, masters, and workers

ARGUMENTS
       provider
              name of the provider source to use

       cluster
              name of the cluster to create

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --non-interactive
              fail instead of prompting for missing values

ENVIRONMENT
       MASTERS
              space-separated list of master node groups (format: type:count[:key=val,key2=val2])

       WORKERS
              space-separated list of worker node groups (format: type:count[:key=val,key2=val2])

       USER_DATA
              optional user-data script

       NETWORK_NAME
              name of the private network (default: private)
EOF
}

_create_nodes() {
    _CONFIG_FILE="$1"
    _PURPOSE="$2"
    export _PURPOSE_DIR="$CLUSTER_DIR/$_PURPOSE"
    if [ -d "$_PURPOSE_DIR" ]; then
        _fail "cluster nodes for $_PURPOSE already exist"
    fi
    mkdir -p "$_PURPOSE_DIR"
    ssh-keygen -t rsa -b 4096 -f "$_PURPOSE_DIR/id_rsa" -N "" -C "rock8s-$_CLUSTER-$_PURPOSE"
    chmod 600 "$_PURPOSE_DIR/id_rsa"
    chmod 644 "$_PURPOSE_DIR/id_rsa.pub"
    case "$_PURPOSE" in
        pfsense)
            _yaml2json < "$_CONFIG_FILE" | jq '.pfsense as $p | . + {nodes: $p} | del(.pfsense, .masters, .workers)' > "$_PURPOSE_DIR/terraform.tfvars.json"
            ;;
        master)
            _yaml2json < "$_CONFIG_FILE" | jq '.masters as $m | . + {nodes: $m} | del(.pfsense, .masters, .workers)' > "$_PURPOSE_DIR/terraform.tfvars.json"
            ;;
        worker)
            _yaml2json < "$_CONFIG_FILE" | jq '.workers as $w | . + {nodes: $w} | del(.pfsense, .masters, .workers)' > "$_PURPOSE_DIR/terraform.tfvars.json"
            ;;
    esac
    export TF_VAR_user_data="#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "$_PURPOSE_DIR/id_rsa.pub")
"
    export TF_VAR_cluster_name="$_CLUSTER"
    export TF_VAR_purpose="$_PURPOSE"
    export TF_VAR_ssh_public_key_path="$_PURPOSE_DIR/id_rsa.pub"
    export TF_VAR_cluster_dir="$CLUSTER_DIR"
    if [ -f "$CLUSTER_DIR/provider/variables.sh" ]; then
        . "$CLUSTER_DIR/provider/variables.sh"
    fi
    cd "$CLUSTER_DIR/provider"
    echo terraform init -backend-true -backend-config="path=$_PURPOSE_DIR/terraform.tfstate" >&2
    echo terraform apply -auto-approve -state="$_PURPOSE_DIR/terraform.tfstate" -var-file="$_PURPOSE_DIR/terraform.tfvars.json" >&2
    echo terraform output -json > "$_PURPOSE_DIR/output.json" >&2
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _PROVIDER=""
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
            -*)
                _help
                exit 1
                ;;
            *)
                if [ -z "$_PROVIDER" ]; then
                    _PROVIDER="$1"
                    shift
                elif [ -z "$_CLUSTER" ]; then
                    _CLUSTER="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done
    if [ -z "$_PROVIDER" ] || [ -z "$_CLUSTER" ]; then
        _help
        exit 1
    fi
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    _ensure_system
    if [ ! -d "$_PROVIDER_DIR" ]; then
        _fail "provider $_PROVIDER not found"
    fi
    export CLUSTER_DIR="$ROCK8S_STATE_HOME/$_TENANT/clusters/$_CLUSTER"
    if [ -d "$CLUSTER_DIR" ]; then
        _fail "cluster $_CLUSTER already exists"
    fi
    _CONFIG_FILE="$ROCK8S_CONFIG_HOME/tenants/$_TENANT/clusters/$_CLUSTER/config.yaml"
    if [ -f "$_PROVIDER_DIR/config.sh" ] && [ ! -f "$_CONFIG_FILE" ] && [ "$_NON_INTERACTIVE" = "0" ]; then
        mkdir -p "$(dirname "$_CONFIG_FILE")"
        { _ERROR="$(sh "$_PROVIDER_DIR/config.sh" "$_CONFIG_FILE")"; _EXIT_CODE="$?"; } || true
        if [ "$_EXIT_CODE" -ne 0 ]; then
            if [ -n "$_ERROR" ]; then
                _fail "$_ERROR"
            else
                _fail "provider config script failed"
            fi
        fi
        if [ ! -f "$_CONFIG_FILE" ]; then
            _fail "provider config script failed to create config file"
        fi
    fi
    mkdir -p "$CLUSTER_DIR"
    cp -r "$_PROVIDER_DIR" "$CLUSTER_DIR/provider"
    for _PURPOSE in "pfsense" "master" "worker"; do
        _create_nodes "$_CONFIG_FILE" "$_PURPOSE"
    done
    printf '{"name":"%s","provider":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" | \
        _format_output "$_FORMAT"
}

_main "$@"
