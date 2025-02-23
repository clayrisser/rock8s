#!/bin/sh

export WHIPTAIL_OK=0
export WHIPTAIL_CANCEL=1
export WHIPTAIL_ESC=255
export WHIPTAIL_ERROR=255

_handle_whiptail_exit() {
    _EXIT_CODE=$1
    case $_EXIT_CODE in
        $WHIPTAIL_CANCEL|$WHIPTAIL_ESC)
            return 1
            ;;
    esac
    return 0
}

prompt_text() {
    _PROMPT="$1"
    _ENV_VAR="$2"
    _DEFAULT="$3"
    _ENV_VALUE=""
    if [ -n "$_ENV_VAR" ]; then
        eval "_ENV_VALUE=\$$_ENV_VAR"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$_ENV_VALUE" ]; then
            echo "$_ENV_VALUE"
            return 0
        elif [ -n "$_DEFAULT" ]; then
            echo "$_DEFAULT"
            return 0
        else
            _fail "missing required value: $_PROMPT"
        fi
    fi
    _EFFECTIVE_DEFAULT="${_ENV_VALUE:-$_DEFAULT}"
    _ANSWER=$(whiptail --title "Input Required" \
        --backtitle "Rock8s Configuration" \
        --inputbox "$_PROMPT" \
        0 0 \
        "$_EFFECTIVE_DEFAULT" \
        3>&1 1>&2 2>&3)
    _EXIT_CODE=$?
    if ! _handle_whiptail_exit $_EXIT_CODE; then
        return 1
    fi
    [ -z "$_ANSWER" ] && _ANSWER="$_EFFECTIVE_DEFAULT"
    echo "$_ANSWER"
}

prompt_password() {
    _PROMPT="$1"
    _ENV_VAR="$2"
    _ENV_VALUE=""
    if [ -n "$_ENV_VAR" ]; then
        eval "_ENV_VALUE=\$$_ENV_VAR"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$_ENV_VALUE" ]; then
            echo "$_ENV_VALUE"
            return 0
        else
            _fail "missing required password: $_PROMPT"
        fi
    fi
    _ANSWER=$(whiptail --title "Password Required" \
        --backtitle "Rock8s Configuration" \
        --passwordbox "$_PROMPT" \
        0 0 \
        3>&1 1>&2 2>&3)
    _EXIT_CODE=$?
    if ! _handle_whiptail_exit $_EXIT_CODE; then
        [ -n "$_ENV_VALUE" ] && echo "$_ENV_VALUE" || return 1
    fi
    echo "$_ANSWER"
}

prompt_boolean() {
    _PROMPT="$1"
    _ENV_VAR="$2"
    _DEFAULT="$3"
    _ENV_VALUE=""
    if [ -n "$_ENV_VAR" ]; then
        eval "_ENV_VALUE=\$$_ENV_VAR"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$_ENV_VALUE" ]; then
            echo "$_ENV_VALUE"
            return 0
        elif [ -n "$_DEFAULT" ]; then
            echo "$_DEFAULT"
            return 0
        else
            _fail "missing required boolean: $_PROMPT"
        fi
    fi
    _EFFECTIVE_DEFAULT="${_ENV_VALUE:-$_DEFAULT}"
    if [ "$_EFFECTIVE_DEFAULT" = "0" ]; then
        _DEFAULT_NO="--defaultno"
    else
        _DEFAULT_NO=""
    fi
    { whiptail --title "Choose Yes/No" \
        --backtitle "Rock8s Configuration" \
        $_DEFAULT_NO \
        --yesno "$_PROMPT" \
        0 0 \
        3>&1 1>&2 2>&3; _EXIT_CODE=$?; } || true
    if [ $_EXIT_CODE -eq $WHIPTAIL_OK ]; then
        echo "1"
    else
        echo "0"
    fi
    return 0
}

prompt_enum() {
    _PROMPT="$1"
    _ENV_VAR="$2"
    _DEFAULT="$3"
    shift 3
    _ENV_VALUE=""
    if [ -n "$_ENV_VAR" ]; then
        eval "_ENV_VALUE=\$$_ENV_VAR"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$_ENV_VALUE" ]; then
            if ! validate_enum "$_ENV_VALUE" "$@"; then
                _fail "invalid value for $_PROMPT: $_ENV_VALUE"
            fi
            echo "$_ENV_VALUE"
            return 0
        elif [ -n "$_DEFAULT" ]; then
            echo "$_DEFAULT"
            return 0
        else
            _fail "missing required value: $_PROMPT"
        fi
    fi
    _EFFECTIVE_DEFAULT="${_ENV_VALUE:-$_DEFAULT}"
    _MENU_ITEMS=""
    for _OPTION in "$@"; do
        _MENU_ITEMS="$_MENU_ITEMS $_OPTION $_OPTION"
    done
    _ANSWER=$(whiptail --title "Select Option" \
        --backtitle "Rock8s Configuration" \
        --default-item "$_EFFECTIVE_DEFAULT" \
        --notags \
        --menu "$_PROMPT" \
        0 0 \
        $# \
        $_MENU_ITEMS \
        3>&1 1>&2 2>&3)
    _EXIT_CODE=$?
    if ! _handle_whiptail_exit $_EXIT_CODE; then
        echo "$_EFFECTIVE_DEFAULT"
        return
    fi
    echo "$_ANSWER"
}

validate_enum() {
    _VALUE="$1"
    shift
    _OPTIONS="$*"
    for _OPTION in $_OPTIONS; do
        if [ "$_VALUE" = "$_OPTION" ]; then
            return 0
        fi
    done
    return 1
}

json2yaml() {
    /usr/bin/python3 -c 'import sys, yaml, json; print(yaml.dump(json.loads(sys.stdin.read()), default_flow_style=False))'
}

yaml2json() {
    /usr/bin/python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'
}

get_config() {
    _JQ_FILTER="$1"
    _DEFAULT_VALUE="$2"
    if [ -n "$_DEFAULT_VALUE" ]; then
        echo "$_DEFAULT_VALUE"
        return 0
    fi
    _RESULT=""
    IFS=:
    for _CONFIG_DIR in $ROCK8S_CONFIG_DIRS; do
        _CONFIG_FILE="$_CONFIG_DIR/config.yaml"
        if [ -f "$_CONFIG_FILE" ]; then
            _JSON="$(yaml2json < "$_CONFIG_FILE")"
            _VALUE="$(echo "$_JSON" | jq -r "$_JQ_FILTER" 2>/dev/null)"
            if [ -n "$_VALUE" ] && [ "$_VALUE" != "null" ]; then
                _RESULT="$_VALUE"
            fi
        fi
        if [ "$_CONFIG_DIR" = "$ROCK8S_CONFIG_HOME" ] && [ -n "$ROCK8S_TENANT" ]; then
            _TENANT_CONFIG="$_CONFIG_DIR/tenants/$ROCK8S_TENANT/config.yaml"
            if [ -f "$_TENANT_CONFIG" ]; then
                _JSON="$(yaml2json < "$_TENANT_CONFIG")"
                _VALUE="$(echo "$_JSON" | jq -r "$_JQ_FILTER" 2>/dev/null)"
                if [ -n "$_VALUE" ] && [ "$_VALUE" != "null" ]; then
                    _RESULT="$_VALUE"
                fi
            fi
        fi
    done
    unset IFS
    echo "$_RESULT"
    return 0
}

validate_ipv4() {
    echo "$1" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' >/dev/null || return 1
    IFS=.
    for _OCTET in $1; do
        [ "$_OCTET" -le 255 ] || return 1
    done
    unset IFS
    return 0
}

validate_hostname() {
    echo "$1" | grep -E '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$' >/dev/null || return 1
    return 0
}
