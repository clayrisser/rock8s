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
    return
}

prompt_text() {
    _PROMPT="$1"
    _ENV_VAR="$2"
    _DEFAULT="$3"
    _REQUIRED="${4:-0}"
    _ENV_VALUE=""
    if [ -n "$_ENV_VAR" ]; then
        eval "_ENV_VALUE=\$$_ENV_VAR"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$_ENV_VALUE" ]; then
            echo "$_ENV_VALUE"
            return
        elif [ -n "$_DEFAULT" ]; then
            echo "$_DEFAULT"
            return
        elif [ "$_REQUIRED" = "1" ]; then
            _fail "missing required value: $_PROMPT"
        else
            echo ""
            return
        fi
    fi
    _EFFECTIVE_DEFAULT="${_ENV_VALUE:-$_DEFAULT}"
    _TITLE="Input Required"
    [ "$_REQUIRED" = "0" ] && _TITLE="Input Optional"
    while true; do
        { _ANSWER=$(whiptail --title "$_TITLE" \
            --backtitle "Rock8s Configuration" \
            --inputbox "$_PROMPT" \
            10 60 \
            "$_EFFECTIVE_DEFAULT" \
            3>&1 1>&2 2>&3); _EXIT_CODE=$?; } || true
        if [ $_EXIT_CODE -eq $WHIPTAIL_CANCEL ] || [ $_EXIT_CODE -eq $WHIPTAIL_ESC ]; then
            return 1
        fi
        _TRIMMED_ANSWER="$(echo "$_ANSWER" | tr -d '[:space:]')"
        if [ "$_REQUIRED" = "1" ] && [ -z "$_TRIMMED_ANSWER" ]; then
            { whiptail --title "Error" \
                --backtitle "Rock8s Configuration" \
                --infobox "This field is required. Please enter a value." \
                0 0 \
                3>&1 1>&2 2>&3; } || true
            continue
        fi
        [ -z "$_ANSWER" ] && _ANSWER="$_EFFECTIVE_DEFAULT"
        break
    done
    echo "$_ANSWER"
}

prompt_password() {
    _PROMPT="$1"
    _ENV_VAR="$2"
    _REQUIRED="${3:-0}"
    _ENV_VALUE=""
    if [ -n "$_ENV_VAR" ]; then
        eval "_ENV_VALUE=\$$_ENV_VAR"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$_ENV_VALUE" ]; then
            echo "$_ENV_VALUE"
            return
        elif [ "$_REQUIRED" = "1" ]; then
            _fail "missing required password: $_PROMPT"
        else
            echo ""
            return
        fi
    fi
    _TITLE="Password Required"
    [ "$_REQUIRED" = "0" ] && _TITLE="Password Optional"
    while true; do
        { _ANSWER=$(whiptail --title "$_TITLE" \
            --backtitle "Rock8s Configuration" \
            --passwordbox "$_PROMPT" \
            10 60 \
            3>&1 1>&2 2>&3); _EXIT_CODE=$?; } || true
        if [ $_EXIT_CODE -eq $WHIPTAIL_CANCEL ] || [ $_EXIT_CODE -eq $WHIPTAIL_ESC ]; then
            if [ "$_REQUIRED" = "0" ] && [ -n "$_ENV_VALUE" ]; then
                echo "$_ENV_VALUE"
            else
                return 1
            fi
        fi
        _TRIMMED_ANSWER="$(echo "$_ANSWER" | tr -d '[:space:]')"
        if [ "$_REQUIRED" = "1" ] && [ -z "$_TRIMMED_ANSWER" ]; then
            { whiptail --title "Error" \
                --backtitle "Rock8s Configuration" \
                --infobox "This field is required. Please enter a value." \
                0 0 \
                3>&1 1>&2 2>&3; } || true
            continue
        fi
        break
    done
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
            return
        elif [ -n "$_DEFAULT" ]; then
            echo "$_DEFAULT"
            return
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
    return
}

prompt_select() {
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
            return
        elif [ -n "$_DEFAULT" ]; then
            echo "$_DEFAULT"
            return
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
        0 0 0 \
        $_MENU_ITEMS \
        3>&1 1>&2 2>&3)
    _EXIT_CODE=$?
    if ! _handle_whiptail_exit $_EXIT_CODE; then
        echo "$_EFFECTIVE_DEFAULT"
        return
    fi
    echo "$_ANSWER"
}

prompt_multiselect() {
    _PROMPT="$1"
    _ENV_VAR="$2"
    shift 2
    _ENV_VALUE=""
    if [ -n "$_ENV_VAR" ]; then
        eval "_ENV_VALUE=\$$_ENV_VAR"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$_ENV_VALUE" ]; then
            echo "$_ENV_VALUE"
            return
        else
            echo ""
            return
        fi
    fi
    _MENU_ITEMS=""
    _ITEM_COUNT=0
    for _OPTION in "$@"; do
        _IS_DEFAULT="OFF"
        for _DEFAULT in $_ENV_VALUE; do
            if [ "$_OPTION" = "$_DEFAULT" ]; then
                _IS_DEFAULT="ON"
                break
            fi
        done
        _MENU_ITEMS="$_MENU_ITEMS $_OPTION $_OPTION $_IS_DEFAULT"
        _ITEM_COUNT=$((_ITEM_COUNT + 1))
    done
    _ANSWER=$(whiptail --title "Select Options" \
        --backtitle "Rock8s Configuration" \
        --separate-output \
        --notags \
        --checklist "$_PROMPT" \
        0 0 0 \
        $_MENU_ITEMS \
        3>&1 1>&2 2>&3)
    _EXIT_CODE=$?
    if ! _handle_whiptail_exit $_EXIT_CODE; then
        echo ""
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
            return
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
        return
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
    return
}
