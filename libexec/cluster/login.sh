#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_TEMP_FILES=""
_cleanup() {
    if [ -n "$_TEMP_FILES" ]; then
        for file in $_TEMP_FILES; do
            [ -f "$file" ] && rm -rf "$file" || true
        done
    fi
}

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster login

SYNOPSIS
       rock8s cluster login [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--kubeconfig <path>]

DESCRIPTION
       login to kubernetes cluster

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

EXAMPLE
       # login to a cluster
       rock8s cluster login --cluster mycluster

       # login with a specific kubeconfig path
       rock8s cluster login --cluster mycluster --kubeconfig ~/.kube/my-config

       # login with json output format
       rock8s cluster login --cluster mycluster -o json

SEE ALSO
       rock8s cluster install --help
       rock8s cluster addons --help
       rock8s cluster upgrade --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    cluster="$ROCK8S_CLUSTER"
    tenant="$ROCK8S_TENANT"
    kubeconfig="$HOME/.kube/config"
    trap _cleanup EXIT INT TERM
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit
                ;;
            -o|--output|-o=*|--output=*)
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
            -t|--tenant|-t=*|--tenant=*)
                case "$1" in
                    *=*)
                        tenant="${1#*=}"
                        shift
                        ;;
                    *)
                        tenant="$2"
                        shift 2
                        ;;
                esac
                ;;
            -c|--cluster|-c=*|--cluster=*)
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
            --kubeconfig|--kubeconfig=*)
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
    if [ -z "$cluster" ]; then
        fail "cluster name required"
    fi
    export ROCK8S_TENANT="$tenant"
    export ROCK8S_CLUSTER="$cluster"
    if [ -z "$kubeconfig" ]; then
        kubeconfig="$HOME/.kube/config"
    fi
    kubeconfig_tmp="$(mktemp)"
    _TEMP_FILES="$_TEMP_FILES $kubeconfig_tmp"
    entrypoint="$(get_entrypoint)"
    first_master_private_ipv4="$(get_master_private_ipv4s | head -n 1)"
    if ! ssh -i "$(get_master_ssh_private_key)" -o StrictHostKeyChecking=no "admin@$first_master_private_ipv4" sudo cat /etc/kubernetes/admin.conf > "$kubeconfig_tmp"; then
        fail "failed to retrieve kubeconfig from master node"
    fi
    current_context=$(kubectl --kubeconfig="$kubeconfig_tmp" config current-context)
    current_cluster=$(kubectl --kubeconfig="$kubeconfig_tmp" config view -o jsonpath='{.contexts[?(@.name == "'$current_context'")].context.cluster}')
    current_user=$(kubectl --kubeconfig="$kubeconfig_tmp" config view -o jsonpath='{.contexts[?(@.name == "'$current_context'")].context.user}')
    kubeconfig_json_tmp="$(mktemp)"
    _TEMP_FILES="$_TEMP_FILES $kubeconfig_json_tmp"
    kubectl --kubeconfig="$kubeconfig_tmp" config view --raw -o json | \
        jq --arg cluster "$current_cluster" --arg context "$current_context" --arg user "$current_user" \
        --arg name "$entrypoint" \
        '(.clusters[] | select(.name == $cluster).name) = $name |
        (.users[] | select(.name == $user).name) = $name |
        .contexts |= map(
        if .name == $context
        then . + {
            "name": $name,
            "context": {
            "cluster": $name,
            "user": $name
            }
        }
        else .
        end
        ) |
        .["current-context"] = $name' > "$kubeconfig_json_tmp"
    json2yaml < "$kubeconfig_json_tmp" > "$kubeconfig_tmp"
    rm -f "$kubeconfig_json_tmp"
    entrypoint_ipv4="$(_resolve_hostname "$entrypoint")"
    if [ -n "$entrypoint_ipv4" ]; then
        kubectl --kubeconfig="$kubeconfig_tmp" config set-cluster "$entrypoint" --server="https://$entrypoint_ipv4:6443" >/dev/null
    else
        kubectl --kubeconfig="$kubeconfig_tmp" config set-cluster "$entrypoint" --server="https://$(get_master_private_ipv4s | head -n 1):6443" >/dev/null
    fi
    if ! kubectl --kubeconfig="$kubeconfig_tmp" config view -o yaml >/dev/null 2>&1; then
        fail "invalid kubeconfig"
    fi
    context_name=$(kubectl --kubeconfig="$kubeconfig_tmp" config view -o json | jq -r '.["current-context"]')
    mkdir -p "$(dirname "$kubeconfig")"
    if [ -f "$kubeconfig" ]; then
        kubeconfig_merged_tmp="$(mktemp)"
        _TEMP_FILES="$_TEMP_FILES $kubeconfig_merged_tmp"
        KUBECONFIG="$kubeconfig:$kubeconfig_tmp" kubectl config view --flatten > "$kubeconfig_merged_tmp"
        mv "$kubeconfig_merged_tmp" "$kubeconfig"
    else
        mv "$kubeconfig_tmp" "$kubeconfig"
    fi
    chmod 600 "$kubeconfig"
    kubectl --kubeconfig="$kubeconfig" config use-context "$context_name" >&2
    _cleanup
    printf '{"cluster":"%s","provider":"%s","tenant":"%s","entrypoint":"%s","kubeconfig":"%s"}\n' \
        "$cluster" "$(get_provider)" "$tenant" "$entrypoint" "$kubeconfig" | format_output "$output"
}

_main "$@"
