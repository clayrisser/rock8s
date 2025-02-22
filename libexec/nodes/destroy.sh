#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes destroy - destroy cluster nodes

SYNOPSIS
       rock8s nodes destroy [-h] [-o <format>] [--non-interactive] [--cluster <cluster>] [--tenant <tenant>] [--force] <provider> <purpose>

DESCRIPTION
       destroy cluster nodes for a specific purpose (pfsense, master, or worker)

ARGUMENTS
       provider
              name of the provider source to use

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
              name of the cluster to destroy nodes for (required)

       --force
              skip dependency checks for destruction order

       --non-interactive
              fail instead of prompting for missing values
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _PROVIDER=""
    _PURPOSE=""
    _CLUSTER=""
    _NON_INTERACTIVE=0
    _FORCE=0
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
                elif [ -z "$_PURPOSE" ]; then
                    _PURPOSE="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done
    if [ -z "$_PROVIDER" ] || [ -z "$_PURPOSE" ] || [ -z "$_CLUSTER" ]; then
        _help
        exit 1
    fi
    if ! echo "$_PURPOSE" | grep -qE '^(pfsense|master|worker)$'; then
        _fail "invalid purpose: $_PURPOSE"
    fi
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    _ensure_system
    if [ ! -d "$_PROVIDER_DIR" ]; then
        _fail "provider $_PROVIDER not found"
    fi
    export CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$_TENANT/clusters/$_CLUSTER"
    if [ ! -d "$CLUSTER_DIR" ]; then
        _fail "cluster $_CLUSTER does not exist"
    fi
    export _PURPOSE_DIR="$CLUSTER_DIR/$_PURPOSE"
    if [ ! -d "$_PURPOSE_DIR" ] || [ ! -f "$_PURPOSE_DIR/output.json" ]; then
        _fail "cluster nodes for $_PURPOSE do not exist"
    fi
    if [ "$_FORCE" != "1" ]; then
        case "$_PURPOSE" in
            pfsense)
                if [ -d "$CLUSTER_DIR/master" ] || [ -d "$CLUSTER_DIR/worker" ]; then
                    _fail "master and worker nodes must be destroyed before pfsense nodes"
                fi
                ;;
            master)
                if [ -d "$CLUSTER_DIR/worker" ]; then
                    _fail "worker nodes must be destroyed before master nodes"
                fi
                ;;
        esac
    fi
    cd "$CLUSTER_DIR/provider"
    terraform init -backend=true -backend-config="path=$_PURPOSE_DIR/terraform.tfstate" >&2
    terraform destroy -auto-approve -state="$_PURPOSE_DIR/terraform.tfstate" -var-file="$_PURPOSE_DIR/terraform.tfvars.json" >&2
    rm -rf "$_PURPOSE_DIR"
    if [ ! -d "$CLUSTER_DIR/worker" ] && [ ! -d "$CLUSTER_DIR/master" ]; then
        rm -rf "$CLUSTER_DIR/provider"
    fi
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","purpose":"%s","status":"destroyed"}\n' \
        "$_CLUSTER" "$_PROVIDER" "$_TENANT" "$_PURPOSE" | \
        _format_output "$_FORMAT"
}

_main "$@"
