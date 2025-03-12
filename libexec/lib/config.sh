#!/bin/sh

_get_cluster_dir() {
    if [ -n "$_CLUSTER_DIR" ]; then
        echo "$_CLUSTER_DIR"
        return
    fi
    if [ -z "$ROCK8S_CONFIG_HOME" ]; then
        _fail "ROCK8S_CONFIG_HOME not set"
    fi
    if [ -z "$ROCK8S_TENANT" ]; then
        _fail "ROCK8S_TENANT not set"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        _fail "ROCK8S_CLUSTER not set"
    fi
    _CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER"
    echo "$_CLUSTER_DIR"
}

_get_config_dir() {
    if [ -n "$_CONFIG_DIR" ]; then
        echo "$_CONFIG_DIR"
        return
    fi
    if [ -z "$ROCK8S_CONFIG_HOME" ]; then
        _fail "ROCK8S_CONFIG_HOME not set"
    fi
    if [ -z "$ROCK8S_TENANT" ]; then
        _fail "ROCK8S_TENANT not set"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        _fail "ROCK8S_CLUSTER not set"
    fi
    _CONFIG_DIR="$ROCK8S_CONFIG_HOME/tenants/$ROCK8S_TENANT/clusters/$ROCK8S_CLUSTER"
    echo "$_CONFIG_DIR"
}

_get_config_file() {
    if [ -n "$_CONFIG_FILE" ]; then
        echo "$_CONFIG_FILE"
        return
    fi
    _CONFIG_FILE="$(_get_config_dir)/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        _PROVIDERS_DIR="$ROCK8S_LIB_PATH/providers"
        _PROVIDERS_LIST=""
        for _P in "$_PROVIDERS_DIR"/*/ ; do
            if [ -d "$_P" ]; then
                _PROVIDER="$(basename "$_P")"
                _PROVIDERS_LIST="$_PROVIDERS_LIST $_PROVIDER $_PROVIDER"
            fi
        done
        if [ -z "$_PROVIDERS_LIST" ]; then
            _fail "no providers found"
        fi
        _PROVIDER="$(whiptail --title "Select Provider" --notags --menu "Choose your cloud provider" 0 0 0 $_PROVIDERS_LIST 3>&1 1>&2 2>&3)" || _fail "provider selection cancelled"
        mkdir -p "$(dirname "$_CONFIG_FILE")"
        _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
        if [ -f "$_PROVIDER_DIR/config.sh" ] && [ ! -f "$_CONFIG_FILE" ] && [ "$NON_INTERACTIVE" = "0" ]; then
            export CLUSTER="$_CLUSTER"
            { _ERROR="$(sh "$_PROVIDER_DIR/config.sh" "$_CONFIG_FILE")"; _EXIT_CODE="$?"; } || true
            if [ "$_EXIT_CODE" -ne 0 ]; then
                if [ -n "$_ERROR" ]; then
                    _fail "$_ERROR"
                else
                    _fail "provider config script failed"
                fi
            fi
            if [ -f "$_CONFIG_FILE" ]; then
                { _ERROR="$(sh "$ROCK8S_LIB_PATH/providers/addons.sh" "$_CONFIG_FILE")"; _EXIT_CODE="$?"; } || true
                if [ "$_EXIT_CODE" -ne 0 ]; then
                    if [ -n "$_ERROR" ]; then
                        _fail "$_ERROR"
                    else
                        _fail "addons config script failed"
                    fi
                fi
            fi
            if [ ! -f "$_CONFIG_FILE" ]; then
                _fail "provider config script failed to create config file"
            fi
            { echo "provider: $_PROVIDER"; cat "$_CONFIG_FILE"; } > "$_CONFIG_FILE.tmp" && mv "$_CONFIG_FILE.tmp" "$_CONFIG_FILE"
        fi
        if [ ! -f "$_CONFIG_FILE" ]; then
            _fail "cluster configuration file not found at $_CONFIG_FILE"
        fi
    fi
    echo "$_CONFIG_FILE"
}

_get_config_json() {
    if [ -n "$_CONFIG_JSON" ]; then
        echo "$_CONFIG_JSON"
        return
    fi
    _CONFIG_FILE="$(_get_config_file)"
    _CONFIG_JSON="$(yaml2json < "$_CONFIG_FILE")"
    if [ -z "$_CONFIG_JSON" ]; then
        _fail "failed to convert cluster configuration file to json"
    fi
    echo "$_CONFIG_JSON"
}

_get_provider() {
    if [ -n "$_PROVIDER" ]; then
        echo "$_PROVIDER"
        return
    fi
    _PROVIDER="$(echo "$(_get_config_json)" | jq -r '.provider')"
    if [ -z "$_PROVIDER" ] || [ "$_PROVIDER" = "null" ]; then
        _fail ".provider not found in config.yaml"
    fi
    echo "$_PROVIDER"
}

_get_entrypoint() {
    if [ -n "$_ENTRYPOINT" ]; then
        echo "$_ENTRYPOINT"
        return
    fi
    _ENTRYPOINT="$(_get_config_json | jq -r '.network.entrypoint // ""')"
    if [ -z "$_ENTRYPOINT" ] || [ "$_ENTRYPOINT" = "null" ]; then
        _fail ".network.entrypoint not found in config.yaml"
    fi
    echo "$_ENTRYPOINT"
}

_get_entrypoint_ip() {
    if [ -n "$_ENTRYPOINT_IP" ]; then
        echo "$_ENTRYPOINT_IP"
        return
    fi
    _ENTRYPOINT_IP="$(_resolve_hostname "$(_get_entrypoint)")"
    echo "$_ENTRYPOINT_IP"
}
