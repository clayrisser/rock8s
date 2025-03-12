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
       rock8s cluster login - login to kubernetes cluster

SYNOPSIS
       rock8s cluster login [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--kubeconfig <path>]

DESCRIPTION
       login to kubernetes cluster and configure kubectl

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to login to (required)

       --kubeconfig <path>
              path to the kubeconfig file (default: $HOME/.kube/config)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _KUBECONFIG="$HOME/.kube/config"
    trap _cleanup EXIT INT TERM
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
        _fail "cluster name required"
    fi
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    _ENTRYPOINT="$(_get_entrypoint)"
    _FIRST_MASTER_PRIVATE_IPV4="$(_get_master_private_ipv4s | head -n 1)"
    if [ -z "$_KUBECONFIG" ]; then
        _KUBECONFIG="$HOME/.kube/config"
    fi
    _KUBECONFIG_TMP="$(mktemp)"
    _TEMP_FILES="$_TEMP_FILES $_KUBECONFIG_TMP"
    if ! ssh -i "$(_get_master_ssh_private_key)" -o StrictHostKeyChecking=no "admin@$_FIRST_MASTER_PRIVATE_IPV4" sudo cat /etc/kubernetes/admin.conf > "$_KUBECONFIG_TMP"; then
        _fail "failed to retrieve kubeconfig from master node"
    fi
    if ! kubectl --kubeconfig="$_KUBECONFIG_TMP" config view -o yaml >/dev/null 2>&1; then
        _fail "invalid kubeconfig"
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
        kubectl --kubeconfig="$_KUBECONFIG_TMP" config set-cluster "$_ENTRYPOINT" --server="https://$(_get_master_private_ipv4s | head -n 1):6443" >/dev/null
    fi
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
    _cleanup
    printf '{"name":"%s","entrypoint":"%s","master_ip":"%s","kubeconfig":"%s"}\n' \
        "$_CLUSTER" "$_ENTRYPOINT" "$_FIRST_MASTER_PRIVATE_IPV4" "$_KUBECONFIG" | _format_output "$_FORMAT" cluster
}

_main "$@" 
