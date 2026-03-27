#!/bin/sh

set -e

get_cluster_dir() {
    if [ -n "$_CLUSTER_DIR" ]; then
        echo "$_CLUSTER_DIR"
        return
    fi
    if [ -z "$ROCK8S_CACHE_HOME" ]; then
        fail "ROCK8S_CACHE_HOME not set"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "ROCK8S_CLUSTER not set"
    fi
    _CLUSTER_DIR="$ROCK8S_CACHE_HOME/clusters/$ROCK8S_CLUSTER"
    echo "$_CLUSTER_DIR"
}

get_cluster_config_file() {
    if [ -n "$_CLUSTER_CONFIG_FILE" ]; then
        echo "$_CLUSTER_CONFIG_FILE"
        return
    fi
    if [ -n "$ROCK8S_CONFIG" ]; then
        if [ ! -f "$ROCK8S_CONFIG" ]; then
            fail "config file not found: $ROCK8S_CONFIG"
        fi
        _CLUSTER_CONFIG_FILE="$ROCK8S_CONFIG"
    elif [ -f "$(pwd)/rock8s.yaml" ]; then
        _CLUSTER_CONFIG_FILE="$(pwd)/rock8s.yaml"
    else
        fail "no config file found (use --config or create rock8s.yaml in current directory)"
    fi
    echo "$_CLUSTER_CONFIG_FILE"
}

get_config_json() {
    if [ -n "$_CONFIG_JSON" ]; then
        echo "$_CONFIG_JSON"
        return
    fi
    _CLUSTER_CONFIG_FILE="$(get_cluster_config_file)"
    _CONFIG_JSON="$(yaml2json <"$_CLUSTER_CONFIG_FILE")"
    _CONFIG_JSON="$(echo "$_CONFIG_JSON" | resolve_refs)"
    echo "$_CONFIG_JSON"
}

get_config() {
    jq_filter="$1"
    default_value="$2"
    _CONFIG_JSON="$(get_config_json)"
    result="$(echo "$_CONFIG_JSON" | jq -r "$jq_filter" 2>/dev/null)"
    if [ -n "$result" ] && [ "$result" != "null" ]; then
        echo "$result"
        return
    fi
    echo "$default_value"
}

get_provider() {
    if [ -n "$_PROVIDER" ]; then
        echo "$_PROVIDER"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PROVIDER="$(echo "$_CONFIG_JSON" | jq -r '.provider.type // ""')"
    if [ -z "$_PROVIDER" ]; then
        fail ".provider.type not found in config.yaml"
    fi
    echo "$_PROVIDER"
}

# Azure disallows several usernames including "admin"; VM image user must match k3sup/SSH.
get_node_ssh_user() {
    if [ -n "$_NODE_SSH_USER" ]; then
        echo "$_NODE_SSH_USER"
        return
    fi
    case "$(get_provider)" in
    azure) _NODE_SSH_USER="rock8s" ;;
    *) _NODE_SSH_USER="admin" ;;
    esac
    echo "$_NODE_SSH_USER"
}

get_entrypoint() {
    if [ -n "$_ENTRYPOINT" ]; then
        echo "$_ENTRYPOINT"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _ENTRYPOINT="$(echo "$_CONFIG_JSON" | jq -r '.network.entrypoint // ""')"
    if [ -z "$_ENTRYPOINT" ]; then
        fail ".network.entrypoint not found in config.yaml"
    fi
    echo "$_ENTRYPOINT"
}

get_entrypoint_ipv4() {
    if [ -n "$_ENTRYPOINT_IPV4" ]; then
        echo "$_ENTRYPOINT_IPV4"
        return
    fi
    _ENTRYPOINT_IPV4="$(_resolve_hostname "$(get_entrypoint)" "ipv4")"
    echo "$_ENTRYPOINT_IPV4"
}

get_addons_repo() {
    if [ -n "$_ADDONS_REPO" ]; then
        echo "$_ADDONS_REPO"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _ADDONS_REPO="$(echo "$_CONFIG_JSON" | jq -r '.addons.repo // ""')"
    if [ -z "$_ADDONS_REPO" ]; then
        _ADDONS_REPO="https://gitlab.com/bitspur/rock8s/addons.git"
    fi
    echo "$_ADDONS_REPO"
}

get_addons_version() {
    if [ -n "$_ADDONS_VERSION" ]; then
        echo "$_ADDONS_VERSION"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _ADDONS_VERSION="$(echo "$_CONFIG_JSON" | jq -r '.addons.version // ""')"
    if [ -z "$_ADDONS_VERSION" ]; then
        _ADDONS_VERSION="0.1.0"
    fi
    echo "$_ADDONS_VERSION"
}
