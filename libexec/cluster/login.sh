#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_TEMP_FILES=""
_cleanup() {
    if [ -n "$_TEMP_FILES" ]; then
        for _FILE in $_TEMP_FILES; do
            [ -f "$_FILE" ] && rm -rf "$_FILE" || true
        done
    fi
}

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster login

SYNOPSIS
       rock8s cluster login [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--kubeconfig <path>] [bastion]

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

ARGUMENTS
       bastion
              hostname of bastion server to retrieve kubeconfig from

EXAMPLE
       # login to a cluster
       rock8s cluster login --cluster mycluster

       # login with a specific kubeconfig path
       rock8s cluster login --cluster mycluster --kubeconfig ~/.kube/my-config

       # login with json output format
       rock8s cluster login --cluster mycluster -o json

       # login using a bastion server
       rock8s cluster login --cluster mycluster 192.168.1.10

SEE ALSO
       rock8s cluster install --help
       rock8s cluster addons --help
       rock8s cluster upgrade --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _KUBECONFIG="$HOME/.kube/config"
    _BASTION=""
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
            -*)
                _help
                exit 1
                ;;
            *)
                _BASTION="$1"
                shift
                ;;
        esac
    done
    if [ -z "$_CLUSTER" ]; then
        fail "cluster name required"
    fi
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$_KUBECONFIG" ]; then
        _KUBECONFIG="$HOME/.kube/config"
    fi
    _KUBECONFIG_TMP="$(mktemp)"
    _TEMP_FILES="$_TEMP_FILES $_KUBECONFIG_TMP"
    if [ -n "$_BASTION" ]; then
        export ROCK8S_SKIP_CONFIG="1"
        if ! ssh "$_BASTION" \
            "cat \$HOME/.local/state/rock8s/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER/kube.yaml" > "$_KUBECONFIG_TMP"; then
            fail "failed to retrieve kubeconfig from master node via bastion server"
        fi
    else
        _ENTRYPOINT="$(get_entrypoint)"
        _FIRST_MASTER_PRIVATE_IPV4="$(get_master_private_ipv4s | head -n 1)"
        if ! ssh -i "$(get_master_ssh_private_key)" -o StrictHostKeyChecking=no "admin@$_FIRST_MASTER_PRIVATE_IPV4" sudo cat /etc/kubernetes/admin.conf > "$_KUBECONFIG_TMP"; then
            fail "failed to retrieve kubeconfig from master node"
        fi
        _CURRENT_CONTEXT=$(kubectl --kubeconfig="$_KUBECONFIG_TMP" config current-context)
        _CURRENT_CLUSTER=$(kubectl --kubeconfig="$_KUBECONFIG_TMP" config view -o jsonpath='{.contexts[?(@.name == "'$_CURRENT_CONTEXT'")].context.cluster}')
        _CURRENT_USER=$(kubectl --kubeconfig="$_KUBECONFIG_TMP" config view -o jsonpath='{.contexts[?(@.name == "'$_CURRENT_CONTEXT'")].context.user}')
        _KUBECONFIG_JSON_TMP="$(mktemp)"
        _TEMP_FILES="$_TEMP_FILES $_KUBECONFIG_JSON_TMP"
        kubectl --kubeconfig="$_KUBECONFIG_TMP" config view --raw -o json | \
            jq --arg cluster "$_CURRENT_CLUSTER" --arg context "$_CURRENT_CONTEXT" --arg user "$_CURRENT_USER" \
            --arg name "$_ENTRYPOINT" \
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
            .["current-context"] = $name' > "$_KUBECONFIG_JSON_TMP"
        json2yaml < "$_KUBECONFIG_JSON_TMP" > "$_KUBECONFIG_TMP"
        rm -f "$_KUBECONFIG_JSON_TMP"
        _ENTRYPOINT_IPV4="$(_resolve_hostname "$_ENTRYPOINT")"
        if [ -n "$_ENTRYPOINT_IPV4" ]; then
            kubectl --kubeconfig="$_KUBECONFIG_TMP" config set-cluster "$_ENTRYPOINT" --server="https://$_ENTRYPOINT_IPV4:6443" >/dev/null
        else
            kubectl --kubeconfig="$_KUBECONFIG_TMP" config set-cluster "$_ENTRYPOINT" --server="https://$(get_master_private_ipv4s | head -n 1):6443" >/dev/null
        fi
    fi
    if ! kubectl --kubeconfig="$_KUBECONFIG_TMP" config view -o yaml >/dev/null 2>&1; then
        fail "invalid kubeconfig"
    fi
    _CONTEXT_NAME=$(kubectl --kubeconfig="$_KUBECONFIG_TMP" config view -o json | jq -r '.["current-context"]')
    mkdir -p "$(dirname "$_KUBECONFIG")"
    if [ -f "$_KUBECONFIG" ]; then
        _KUBECONFIG_MERGED_TMP="$(mktemp)"
        _TEMP_FILES="$_TEMP_FILES $_KUBECONFIG_MERGED_TMP"
        KUBECONFIG="$_KUBECONFIG:$_KUBECONFIG_TMP" kubectl config view --flatten > "$_KUBECONFIG_MERGED_TMP"
        mv "$_KUBECONFIG_MERGED_TMP" "$_KUBECONFIG"
    else
        mv "$_KUBECONFIG_TMP" "$_KUBECONFIG"
    fi
    chmod 600 "$_KUBECONFIG"
    kubectl --kubeconfig="$_KUBECONFIG" config use-context "$_CONTEXT_NAME" >&2
    _cleanup
    if [ -n "$_BASTION" ]; then
        printf '{"cluster":"%s","provider":"%s","tenant":"%s","kubeconfig":"%s"}\n' \
            "$_CLUSTER" "$(get_provider)" "$_TENANT" "$_KUBECONFIG" | format_output "$_OUTPUT"
    else
        printf '{"cluster":"%s","provider":"%s","tenant":"%s","entrypoint":"%s","kubeconfig":"%s"}\n' \
            "$_CLUSTER" "$(get_provider)" "$_TENANT" "$_ENTRYPOINT" "$_KUBECONFIG" | format_output "$_OUTPUT"
    fi
}

_main "$@"
