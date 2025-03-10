#!/bin/sh

_initialize_provider() {
    _CONFIG_FILE="$1"
    _CLUSTER="$2"
    _NON_INTERACTIVE="${3:-0}"

    if [ -f "$_CONFIG_FILE" ]; then
        _load_config_json "$_CONFIG_FILE" || _fail "failed to load config file"
        _PROVIDER="$(echo "$_CONFIG_JSON" | jq -r '.provider')"
    fi

    if [ -z "$_PROVIDER" ] || [ "$_PROVIDER" = "null" ]; then
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
    fi
    mkdir -p "$(dirname "$_CONFIG_FILE")"
    _PROVIDER_DIR="$ROCK8S_LIB_PATH/providers/$_PROVIDER"
    if [ -f "$_PROVIDER_DIR/config.sh" ] && [ ! -f "$_CONFIG_FILE" ] && [ "$_NON_INTERACTIVE" = "0" ]; then
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
}
