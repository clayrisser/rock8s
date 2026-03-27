#!/bin/sh

set -e

export DIALOG_OK=0
export DIALOG_CANCEL=1
export DIALOG_ESC=255
export DIALOG_ERROR=255

handle_dialog_exit() {
    exit_code=$1
    case $exit_code in
        $DIALOG_CANCEL|$DIALOG_ESC)
            return 1
            ;;
    esac
    return
}

prompt_text() {
    prompt="$1"
    env_var="$2"
    default_val="$3"
    required="${4:-0}"
    env_value=""
    if [ -n "$env_var" ]; then
        eval "env_value=\$$env_var"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$env_value" ]; then
            echo "$env_value"
            return
        elif [ -n "$default_val" ]; then
            echo "$default_val"
            return
        elif [ "$required" = "1" ]; then
            fail "missing required value: $prompt"
        else
            echo ""
            return
        fi
    fi
    effective_default="${env_value:-$default_val}"
    title="Input Required"
    [ "$required" = "0" ] && title="Input Optional"
    while true; do
        { answer=$(dialog --title "$title" \
            --backtitle "Rock8s Configuration" \
            --inputbox "$prompt" \
            10 60 \
            "$effective_default" \
            3>&1 1>&2 2>&3); exit_code=$?; } || true
        if [ $exit_code -eq $DIALOG_CANCEL ] || [ $exit_code -eq $DIALOG_ESC ]; then
            return 1
        fi
        trimmed_answer="$(echo "$answer" | tr -d '[:space:]')"
        if [ "$required" = "1" ] && [ -z "$trimmed_answer" ]; then
            { dialog --title "Error" \
                --backtitle "Rock8s Configuration" \
                --infobox "This field is required. Please enter a value." \
                0 0 \
                3>&1 1>&2 2>&3; } || true
            continue
        fi
        [ -z "$answer" ] && answer="$effective_default"
        break
    done
    echo "$answer"
}

prompt_password() {
    prompt="$1"
    env_var="$2"
    required="${3:-0}"
    env_value=""
    if [ -n "$env_var" ]; then
        eval "env_value=\$$env_var"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$env_value" ]; then
            echo "$env_value"
            return
        elif [ "$required" = "1" ]; then
            fail "missing required password: $prompt"
        else
            echo ""
            return
        fi
    fi
    title="Password Required"
    [ "$required" = "0" ] && title="Password Optional"
    while true; do
        { answer=$(dialog --title "$title" \
            --backtitle "Rock8s Configuration" \
            --insecure \
            --passwordbox "$prompt" \
            10 60 \
            3>&1 1>&2 2>&3); exit_code=$?; } || true
        if [ $exit_code -eq $DIALOG_CANCEL ] || [ $exit_code -eq $DIALOG_ESC ]; then
            if [ "$required" = "0" ] && [ -n "$env_value" ]; then
                echo "$env_value"
            else
                return 1
            fi
        fi
        trimmed_answer="$(echo "$answer" | tr -d '[:space:]')"
        if [ "$required" = "1" ] && [ -z "$trimmed_answer" ]; then
            { dialog --title "Error" \
                --backtitle "Rock8s Configuration" \
                --infobox "This field is required. Please enter a value." \
                0 0 \
                3>&1 1>&2 2>&3; } || true
            continue
        fi
        break
    done
    echo "$answer"
}

prompt_boolean() {
    prompt="$1"
    env_var="$2"
    default_val="$3"
    env_value=""
    if [ -n "$env_var" ]; then
        eval "env_value=\$$env_var"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$env_value" ]; then
            echo "$env_value"
            return
        elif [ -n "$default_val" ]; then
            echo "$default_val"
            return
        else
            fail "missing required boolean: $prompt"
        fi
    fi
    effective_default="${env_value:-$default_val}"
    if [ "$effective_default" = "0" ]; then
        default_no="--defaultno"
    else
        default_no=""
    fi
    { dialog --title "Choose Yes/No" \
        --backtitle "Rock8s Configuration" \
        $default_no \
        --yesno "$prompt" \
        0 0 \
        3>&1 1>&2 2>&3; exit_code=$?; } || true
    if [ $exit_code -eq $DIALOG_OK ]; then
        echo "1"
    else
        echo "0"
    fi
    return
}

prompt_select() {
    prompt="$1"
    env_var="$2"
    default_val="$3"
    shift 3
    env_value=""
    if [ -n "$env_var" ]; then
        eval "env_value=\$$env_var"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$env_value" ]; then
            if ! validate_enum "$env_value" "$@"; then
                fail "invalid value for $prompt: $env_value"
            fi
            echo "$env_value"
            return
        elif [ -n "$default_val" ]; then
            echo "$default_val"
            return
        else
            fail "missing required value: $prompt"
        fi
    fi
    effective_default="${env_value:-$default_val}"
    menu_items=""
    for option in "$@"; do
        menu_items="$menu_items $option $option"
    done
    answer=$(dialog --title "Select Option" \
        --backtitle "Rock8s Configuration" \
        --default-item "$effective_default" \
        --no-tags \
        --menu "$prompt" \
        0 0 0 \
        $menu_items \
        3>&1 1>&2 2>&3)
    exit_code=$?
    if ! handle_dialog_exit $exit_code; then
        echo "$effective_default"
        return
    fi
    echo "$answer"
}

prompt_multiselect() {
    prompt="$1"
    env_var="$2"
    shift 2
    env_value=""
    if [ -n "$env_var" ]; then
        eval "env_value=\$$env_var"
    fi
    if [ "${NON_INTERACTIVE:-0}" = "1" ]; then
        if [ -n "$env_value" ]; then
            echo "$env_value"
            return
        else
            echo ""
            return
        fi
    fi
    menu_items=""
    item_count=0
    for option in "$@"; do
        is_default="OFF"
        for default_item in $env_value; do
            if [ "$option" = "$default_item" ]; then
                is_default="ON"
                break
            fi
        done
        menu_items="$menu_items $option $option $is_default"
        item_count=$((item_count + 1))
    done
    answer=$(dialog --title "Select Options" \
        --backtitle "Rock8s Configuration" \
        --separate-output \
        --no-tags \
        --checklist "$prompt" \
        0 0 0 \
        $menu_items \
        3>&1 1>&2 2>&3)
    exit_code=$?
    if ! handle_dialog_exit $exit_code; then
        echo ""
        return
    fi
    echo "$answer"
}

validate_enum() {
    value="$1"
    shift
    options="$*"
    for option in $options; do
        if [ "$value" = "$option" ]; then
            return
        fi
    done
    return 1
}
