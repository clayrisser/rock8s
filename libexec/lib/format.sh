#!/bin/sh

set -e

format_json_table() {
    _JSON="$1"
    _KEYS="$2"
    [ -z "$_JSON" ] && return
    if [ "$_KEYS" = "-" ]; then
        _KEYS="$(printf "%s\n" "$_JSON" | jq -r 'to_entries | .[].key' | tr '\n' ' ')"
    fi
    _COUNT="$(printf "%s\n" "$_JSON" | jq -s 'length')"
    if [ "$_COUNT" -eq 0 ]; then
        return
    elif [ "$_COUNT" -eq 1 ] && [ "$(printf "%s\n" "$_JSON" | jq -r 'type')" = "object" ]; then
        (
            echo "KEY VALUE"
            for _KEY in $_KEYS; do
                printf "%s %s\n" \
                    "$_KEY" \
                    "$(printf "%s\n" "$_JSON" | jq -r ".$_KEY // \"-\"")"
            done
        ) | column -t
    else
        _HEADER=""
        for _KEY in $_KEYS; do
            _HEADER="$_HEADER $(echo "$_KEY" | tr '[:lower:]' '[:upper:]')"
        done
        _JQ_FILTER=".[] | [$(for _KEY in $_KEYS; do
            if [ "$_KEY" = "$(echo "$_KEYS" | cut -d' ' -f1)" ]; then
                printf ".%s // \"-\"" "$_KEY"
            else
                printf ", .%s // \"-\"" "$_KEY"
            fi
        done)] | @tsv"
        (
            echo "$_HEADER"
            printf "%s\n" "$_JSON" | jq -r "$_JQ_FILTER" | sed -e 's/  */ /g'
        ) | sed 's/^ *//' | column -t
    fi
}

format_output() {
    _FORMAT="${1:-text}"
    _TYPE="$2"
    if [ ! -t 0 ]; then
        _INPUT="$(cat)"
    else
        _INPUT=""
    fi
    case "$_FORMAT" in
        json)
            printf "%s\n" "$_INPUT" | jq
            ;;
        yaml)
            printf "%s\n" "$_INPUT" | while read -r line; do
                echo "---"
                echo "$line" | json2yaml
            done >&2
            ;;
        text)
            case "$_TYPE" in
                providers)
                    printf "%s\n" "$_INPUT" | jq -r '.[] | .name'
                    ;;
                search)
                    format_json_table "$_INPUT" "repo name version path"
                    ;;
                ls)
                    format_json_table "$_INPUT" "name environment status path"
                    ;;
                repo-list)
                    format_json_table "$_INPUT" "path"
                    ;;
                success)
                    printf "${GREEN}%s${NC}\n" "$(echo "$_INPUT" | jq -r '.message')"
                    ;;
                error)
                    printf "${RED}%s${NC}\n" "$(echo "$_INPUT" | jq -r '.error')"
                    return 1
                    ;;
                *)
                    format_json_table "$_INPUT" -
                    ;;
            esac
            ;;
        *)
            printf '{"error":"unsupported output format: %s"}\n' "$_FORMAT" | format_output text error
            return 1
            ;;
    esac
}
