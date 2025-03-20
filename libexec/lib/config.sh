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

get_tenant_config_file() {
    if [ -n "$_TENANT_CONFIG_FILE" ]; then
        echo "$_TENANT_CONFIG_FILE"
        return
    fi
    _TENANT_CONFIG_FILE="$(get_config_dir)/config.yaml"
    if [ ! -f "$_TENANT_CONFIG_FILE" ] && [ -z "$ROCK8S_SKIP_CONFIG" ]; then
        _PROVIDERS_DIR="$ROCK8S_LIB_PATH/providers"
        _PROVIDERS_LIST=""
        for _P in "$_PROVIDERS_DIR"/*/ ; do
            if [ -d "$_P" ]; then
                _PROVIDER="$(basename "$_P")"
                _PROVIDERS_LIST="$_PROVIDERS_LIST $_PROVIDER $_PROVIDER"
            fi
        done
        if [ -z "$_PROVIDERS_LIST" ]; then
            fail "no providers found"
        fi
        _PROVIDER="$(whiptail --title "Select Provider" --notags --menu "Choose your cloud provider" 0 0 0 $_PROVIDERS_LIST 3>&1 1>&2 2>&3)" || fail "provider selection cancelled"
        mkdir -p "$(dirname "$_TENANT_CONFIG_FILE")"
        _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
        if [ -f "$_PROVIDER_DIR/config.sh" ] && [ ! -f "$_TENANT_CONFIG_FILE" ]; then
            . "$_PROVIDER_DIR/config.sh"
            if [ -f "$_TENANT_CONFIG_FILE.tmp" ]; then
                . "$ROCK8S_LIB_PATH/providers/addons.sh"
            fi
            if [ ! -f "$_TENANT_CONFIG_FILE.tmp" ]; then
                fail "provider config script failed to create config file"
            fi
            mv "$_TENANT_CONFIG_FILE.tmp" "$_TENANT_CONFIG_FILE"
            { echo "provider: $_PROVIDER"; cat "$_TENANT_CONFIG_FILE"; } > "$_TENANT_CONFIG_FILE.tmp" && mv "$_TENANT_CONFIG_FILE.tmp" "$_TENANT_CONFIG_FILE"
        fi
        if [ ! -f "$_TENANT_CONFIG_FILE" ]; then
            fail "cluster configuration file not found at $_TENANT_CONFIG_FILE"
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
    for _C in $ROCK8S_CONFIG_DIRS; do
        _CONFIG_FILE="$_C/config.yaml"
        if [ -f "$_CONFIG_FILE" ]; then
            _NEW_JSON="$(yaml2json < "$_CONFIG_FILE")"
            _CONFIG_JSON="$(echo "$_CONFIG_JSON" "$_NEW_JSON" | jq -s '.[0] * .[1]')"
        fi
    done
    unset IFS
    _TENANT_CONFIG_FILE="$(get_tenant_config_file)"
    if [ -f "$_TENANT_CONFIG_FILE" ]; then
        _NEW_JSON="$(yaml2json < "$_TENANT_CONFIG_FILE")"
        _CONFIG_JSON="$(echo "$_CONFIG_JSON" "$_NEW_JSON" | jq -s '.[0] * .[1]')"
    fi
    echo "$_CONFIG_JSON"
}

get_config() {
    _JQ_FILTER="$1"
    _DEFAULT_VALUE="$2"
    _CONFIG_JSON="$(get_config_json)"
    _RESULT="$(echo "$_CONFIG_JSON" | jq -r "$_JQ_FILTER" 2>/dev/null)"
    if [ -n "$_RESULT" ] && [ "$_RESULT" != "null" ]; then
        echo "$_RESULT"
        return
    fi
    echo "$_DEFAULT_VALUE"
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
