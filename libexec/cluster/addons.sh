#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_OLM_VERSION="0.25.0"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster addons

SYNOPSIS
       rock8s cluster addons [-h] [-o <format>] [-y|--yes] [--cluster <cluster>] [--kubeconfig <path>]

DESCRIPTION
       configure cluster addons for an existing kubernetes cluster

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -c, --cluster <cluster>
              cluster name

       --kubeconfig <path>
              path to kubeconfig

       -y, --yes
              automatically approve operations

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
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
    yes="0"
    kubeconfig=""
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            _help
            exit
            ;;
        -o | --output | -o=* | --output=*)
            case "$1" in
            *=*)
                output="${1#*=}"
                shift
                ;;
            *)
                output="$2"
                shift 2
                ;;
            esac
            ;;
        -c | --cluster | -c=* | --cluster=*)
            case "$1" in
            *=*)
                cluster="${1#*=}"
                shift
                ;;
            *)
                cluster="$2"
                shift 2
                ;;
            esac
            ;;
        --kubeconfig | --kubeconfig=*)
            case "$1" in
            *=*)
                kubeconfig="${1#*=}"
                shift
                ;;
            *)
                kubeconfig="$2"
                shift 2
                ;;
            esac
            ;;
        -y | --yes)
            yes="1"
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
    export ROCK8S_CLUSTER="$cluster"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    cluster_dir="$(get_cluster_dir)"
    addons_dir="$cluster_dir/addons"
    mkdir -p "$addons_dir"
    _addons_repo="$(get_addons_source_repo)"
    _addons_version="$(get_addons_source_version)"
    : "${_addons_repo:=https://gitlab.com/bitspur/rock8s/rock8s.git}"
    if [ -n "$_addons_version" ]; then
        _cache_key="${_addons_repo}@${_addons_version}"
        _cached_key=""
        if [ -f "$addons_dir/.source" ]; then
            _cached_key="$(cat "$addons_dir/.source")"
        fi
        if [ ! -d "$addons_dir/repo" ] || [ "$_cached_key" != "$_cache_key" ]; then
            rm -rf "$addons_dir/repo"
            git clone --depth 1 --branch "$_addons_version" \
                "$_addons_repo" "$addons_dir/repo" >&2
            echo "$_cache_key" >"$addons_dir/.source"
        fi
        rm -rf "$addons_dir/terraform"
        if [ -d "$addons_dir/repo/addons" ]; then
            cp -r "$addons_dir/repo/addons" "$addons_dir/terraform"
        else
            cp -r "$addons_dir/repo" "$addons_dir/terraform"
        fi
    else
        rm -rf "$addons_dir/terraform" "$addons_dir/repo" "$addons_dir/.source"
        cp -r "$ROCK8S_HOME/addons" "$addons_dir/terraform"
    fi
    export TF_VAR_cluster_name="$cluster"
    export TF_VAR_entrypoint="$(get_entrypoint)"
    export TF_VAR_kubeconfig="${kubeconfig:-$cluster_dir/kube.yaml}"
    export TF_DATA_DIR="$addons_dir/.terraform"
    load_balancer_enabled="1"
    export TF_VAR_ingress_nginx="{\"load_balancer\":$load_balancer_enabled}"
    config_json="$(get_config_json)"
    config_json=$(echo "$config_json" | jq --arg lb "$load_balancer_enabled" '.addons.ingress_nginx = {"load_balancer": ($lb == "1")}')
    lan_metallb="$(get_lan_metallb)"
    if [ -n "$lan_metallb" ]; then
        config_json=$(echo "$config_json" | jq --arg range "$lan_metallb" 'if .addons.metallb != null and .addons.metallb != false then .addons.metallb.address_range //= $range else . end')
    fi
    echo "$config_json" | jq '.addons | del(.source)' >"$addons_dir/terraform.tfvars.json"
    chmod 600 "$addons_dir/terraform.tfvars.json"
    cd "$addons_dir/terraform"
    state_key="$(get_state_key "$cluster" "addons")"
    generate_backend_config "$state_key" "$addons_dir" >"$addons_dir/terraform/_backend.tf"
    unset_s3_env
    tofu init -upgrade -reconfigure >&2
    mkdir -p "$addons_dir/artifacts/olm"
    if [ ! -f "$addons_dir/artifacts/olm/crds.yaml" ]; then
        curl -sSL "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v${_OLM_VERSION}/crds.yaml" >"$addons_dir/artifacts/olm/crds.yaml"
    fi
    if [ ! -f "$addons_dir/artifacts/olm/olm.yaml" ]; then
        curl -sSL "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v${_OLM_VERSION}/olm.yaml" >"$addons_dir/artifacts/olm/olm.yaml"
    fi
    tofu apply $([ "$yes" = "1" ] && echo "-auto-approve") -var-file="$addons_dir/terraform.tfvars.json" >&2
    tofu output -json >"$addons_dir/output.json"
    printf '{"cluster":"%s","provider":"%s"}\n' \
        "$cluster" "$(get_provider)" |
        format_output "$output"
}

_main "$@"
