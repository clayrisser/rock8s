#!/bin/sh

set -e

get_cluster_dir() {
    if [ -n "$_CLUSTER_DIR" ]; then
        echo "$_CLUSTER_DIR"
        return
    fi
    if [ -z "$ROCK8S_CONFIG_HOME" ]; then
        fail "ROCK8S_CONFIG_HOME not set"
    fi
    if [ -z "$ROCK8S_TENANT" ]; then
        fail "ROCK8S_TENANT not set"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "ROCK8S_CLUSTER not set"
    fi
    _CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER"
    echo "$_CLUSTER_DIR"
}

get_pfsense_dir() {
    if [ -n "$_PFSENSE_DIR" ]; then
        echo "$_PFSENSE_DIR"
        return
    fi
    if [ -z "$ROCK8S_STATE_HOME" ]; then
        fail "ROCK8S_STATE_HOME not set"
    fi
    if [ -z "$ROCK8S_TENANT" ]; then
        fail "ROCK8S_TENANT not set"
    fi
    if [ -z "$ROCK8S_PFSENSE" ]; then
        fail "ROCK8S_PFSENSE not set"
    fi
    _PFSENSE_DIR="$ROCK8S_STATE_HOME/tenants/$ROCK8S_TENANT/pfsense/$ROCK8S_PFSENSE"
    echo "$_PFSENSE_DIR"
}

get_pfsense_config_dir() {
    if [ -n "$_PFSENSE_CONFIG_DIR" ]; then
        echo "$_PFSENSE_CONFIG_DIR"
        return
    fi
    if [ -z "$ROCK8S_CONFIG_HOME" ]; then
        fail "ROCK8S_CONFIG_HOME not set"
    fi
    if [ -z "$ROCK8S_TENANT" ]; then
        fail "ROCK8S_TENANT not set"
    fi
    if [ -z "$ROCK8S_PFSENSE" ]; then
        fail "ROCK8S_PFSENSE not set"
    fi
    _PFSENSE_CONFIG_DIR="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT/pfsense/$ROCK8S_PFSENSE"
    echo "$_PFSENSE_CONFIG_DIR"
}

get_config_dir() {
    if [ -n "$_CONFIG_DIR" ]; then
        echo "$_CONFIG_DIR"
        return
    fi
    if [ -z "$ROCK8S_CONFIG_HOME" ]; then
        fail "ROCK8S_CONFIG_HOME not set"
    fi
    if [ -z "$ROCK8S_TENANT" ]; then
        fail "ROCK8S_TENANT not set"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "ROCK8S_CLUSTER not set"
    fi
    _CONFIG_DIR="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER"
    echo "$_CONFIG_DIR"
}

_generate_config() {
    providers_dir="$ROCK8S_LIB_PATH/providers"
    providers_list=""
    for p in "$providers_dir"/*/ ; do
        if [ -d "$p" ]; then
            prov="$(basename "$p")"
            providers_list="$providers_list $prov $prov"
        fi
    done
    if [ -z "$providers_list" ]; then
        fail "no providers found"
    fi
    prov="$(dialog --title "Select Provider" --no-tags --menu "Choose your cloud provider" 0 0 0 $providers_list 3>&1 1>&2 2>&3)" || fail "provider selection cancelled"
    mkdir -p "$(dirname "$_TENANT_CONFIG_FILE")"
    provider_dir="$ROCK8S_LIB_PATH/providers/$prov"
    config_script="$1"
    if [ -f "$provider_dir/$config_script" ] && [ ! -f "$_TENANT_CONFIG_FILE" ]; then
        . "$provider_dir/$config_script"
        if [ -f "$_TENANT_CONFIG_FILE.tmp" ] && [ "$config_script" = "config.sh" ]; then
            . "$ROCK8S_LIB_PATH/providers/addons.sh"
        fi
        if [ ! -f "$_TENANT_CONFIG_FILE.tmp" ]; then
            fail "provider config script failed to create config file"
        fi
        mv "$_TENANT_CONFIG_FILE.tmp" "$_TENANT_CONFIG_FILE"
        { echo "provider: $prov"; cat "$_TENANT_CONFIG_FILE"; } > "$_TENANT_CONFIG_FILE.tmp" && mv "$_TENANT_CONFIG_FILE.tmp" "$_TENANT_CONFIG_FILE"
    fi
    if [ ! -f "$_TENANT_CONFIG_FILE" ]; then
        fail "configuration file not found at $_TENANT_CONFIG_FILE"
    fi
}

get_tenant_config_file() {
    if [ -n "$_TENANT_CONFIG_FILE" ]; then
        echo "$_TENANT_CONFIG_FILE"
        return
    fi
    if [ -n "$ROCK8S_PFSENSE" ] && [ -z "$ROCK8S_CLUSTER" ]; then
        _TENANT_CONFIG_FILE="$(get_pfsense_config_dir)/config.yaml"
    else
        _TENANT_CONFIG_FILE="$(get_config_dir)/config.yaml"
    fi
    if [ ! -f "$_TENANT_CONFIG_FILE" ] && [ -z "$ROCK8S_SKIP_CONFIG" ]; then
        if [ -n "$ROCK8S_PFSENSE" ] && [ -z "$ROCK8S_CLUSTER" ]; then
            _generate_config "pfsense_config.sh"
        else
            _generate_config "config.sh"
        fi
    fi
    echo "$_TENANT_CONFIG_FILE"
}

get_config_json() {
    if [ -n "$_CONFIG_JSON" ]; then
        echo "$_CONFIG_JSON"
        return
    fi
    _CONFIG_JSON="{}"
    IFS=:
    for c in $ROCK8S_CONFIG_DIRS; do
        config_file="$c/config.yaml"
        if [ -f "$config_file" ]; then
            new_json="$(yaml2json < "$config_file")"
            _CONFIG_JSON="$(echo "$_CONFIG_JSON" "$new_json" | jq -s '.[0] * .[1]')"
        fi
    done
    unset IFS
    _TENANT_CONFIG_FILE="$(get_tenant_config_file)"
    if [ -f "$_TENANT_CONFIG_FILE" ]; then
        new_json="$(yaml2json < "$_TENANT_CONFIG_FILE")"
        _CONFIG_JSON="$(echo "$_CONFIG_JSON" "$new_json" | jq -s '.[0] * .[1]')"
    fi
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
    _PROVIDER="$(echo "$_CONFIG_JSON" | jq -r '.provider // ""')"
    if [ -z "$_PROVIDER" ]; then
        fail ".provider not found in config.yaml"
    fi
    echo "$_PROVIDER"
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

get_entrypoint_ipv6() {
    if [ -n "$_ENTRYPOINT_IPV6" ]; then
        echo "$_ENTRYPOINT_IPV6"
        return
    fi
    _ENTRYPOINT_IPV6="$(_resolve_hostname "$(get_entrypoint)" "ipv6")"
    echo "$_ENTRYPOINT_IPV6"
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
