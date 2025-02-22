#!/bin/sh

export DIALOG_OK=0
export DIALOG_CANCEL=1
export DIALOG_ESC=255
export DIALOG_ERROR=255
export DIALOGOPTS="--colors --no-collapse"

_get_term_size() {
    if command -v tput >/dev/null 2>&1; then
        _ROWS=$(tput lines)
        _COLS=$(tput cols)
    else
        _ROWS=24
        _COLS=80
    fi
}

_handle_dialog_exit() {
    _EXIT_CODE=$1
    case $_EXIT_CODE in
        $DIALOG_CANCEL|$DIALOG_ESC)
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
    _get_term_size
    _ANSWER=$(dialog --title "Input Required" \
                     --backtitle "Rock8s Configuration" \
                     --inputbox "\Z1$_PROMPT\Zn" \
                     $((_ROWS - 8)) $((_COLS - 8)) \
                     "$_EFFECTIVE_DEFAULT" \
                     2>&1 >/dev/tty)
    _EXIT_CODE=$?
    if ! _handle_dialog_exit $_EXIT_CODE; then
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
    _get_term_size
    _ANSWER=$(dialog --title "Password Required" \
                     --backtitle "Rock8s Configuration" \
                     --insecure \
                     --passwordbox "\Z1$_PROMPT\Zn" \
                     $((_ROWS - 8)) $((_COLS - 8)) \
                     "${_ENV_VALUE:-}" \
                     2>&1 >/dev/tty)
    _EXIT_CODE=$?
    if ! _handle_dialog_exit $_EXIT_CODE; then
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
    _get_term_size

    if [ "$_EFFECTIVE_DEFAULT" = "1" ]; then
        _DEFAULT_NO="--defaultno"
    else
        _DEFAULT_NO=""
    fi

    dialog --title "Choose Yes/No" \
           --backtitle "Rock8s Configuration" \
           $_DEFAULT_NO \
           --yesno "\Z1$_PROMPT\Zn" \
           $((_ROWS - 8)) $((_COLS - 8)) \
           2>&1 >/dev/tty

    case $? in
        0) echo "1" ;;
        *) echo "0" ;;
    esac
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

    _get_term_size
    _ANSWER=$(dialog --title "Select Option" \
                     --backtitle "Rock8s Configuration" \
                     --default-item "$_EFFECTIVE_DEFAULT" \
                     --no-tags \
                     --menu "\Z1$_PROMPT\Zn" \
                     $((_ROWS - 8)) $((_COLS - 8)) \
                     $# \
                     $_MENU_ITEMS \
                     2>&1 >/dev/tty)
    _EXIT_CODE=$?
    if ! _handle_dialog_exit $_EXIT_CODE; then
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
    perl -MJSON::PP -MYAML -e '
        my $json = do { local $/; <STDIN> };
        my $data = decode_json($json);
        print Dump($data);
    '
}

yaml2json() {
    python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'
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
            _VALUE="$(yaml2json < "$_CONFIG_FILE" | jq -r "$_JQ_FILTER" 2>/dev/null)"
            if [ -n "$_VALUE" ]; then
                _RESULT="$_VALUE"
            fi
        fi
        if [ "$_CONFIG_DIR" = "$ROCK8S_CONFIG_HOME" ] && [ -n "$ROCK8S_TENANT" ]; then
            _TENANT_CONFIG="$_CONFIG_DIR/tenants/$ROCK8S_TENANT/config.yaml"
            if [ -f "$_TENANT_CONFIG" ]; then
                _VALUE="$(yaml2json < "$_TENANT_CONFIG" | jq -r "$_JQ_FILTER" 2>/dev/null)"
                if [ -n "$_VALUE" ]; then
                    _RESULT="$_VALUE"
                fi
            fi
        fi
    done
    unset IFS
    echo "$_RESULT"
    return 0
}
