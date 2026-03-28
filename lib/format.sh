#!/bin/sh

set -e

format_json_table() {
    json="$1"
    keys="$2"
    [ -z "$json" ] && return
    _tmpfile=$(mktemp)
    type=$(printf "%s\n" "$json" | jq -r 'type')
    if [ "$type" = "object" ]; then
        key_count=$(printf "%s\n" "$json" | jq -r 'keys | length')
        if [ "$key_count" -eq 1 ]; then
            single_key=$(printf "%s\n" "$json" | jq -r 'keys[0]')
            single_value=$(printf "%s\n" "$json" | jq -r --arg k "$single_key" '.[$k] | if type == "object" or type == "array" then tojson else tostring end')
            echo "$single_value"
            rm -f "$_tmpfile"
            return
        fi
    fi
    if [ "$keys" = "-" ]; then
        if [ "$type" = "array" ]; then
            array_length=$(printf "%s\n" "$json" | jq 'length')
            if [ "$array_length" -eq 0 ]; then
                rm -f "$_tmpfile"
                return
            fi
            keys=$(printf "%s\n" "$json" | jq -r '.[0] | keys | join(" ")')
        else
            keys=$(printf "%s\n" "$json" | jq -r 'keys | join(" ")')
        fi
    fi
    for key in $keys; do
        printf "%s⋮" "$(echo "$key" | tr '[:lower:]' '[:upper:]')" >>"$_tmpfile"
    done
    printf "\n" >>"$_tmpfile"
    if [ "$type" = "array" ]; then
        length=$(printf "%s\n" "$json" | jq 'length')
        for i in $(seq 0 $((length - 1))); do
            for key in $keys; do
                value=$(printf "%s\n" "$json" | jq -r --arg k "$key" "try (.[${i}] | .[\$k] | if type == \"object\" or type == \"array\" then tojson else tostring end) catch \"-\"")
                value=$(echo "$value" | tr '⋮' ' ')
                printf "%s⋮" "$value" >>"$_tmpfile"
            done
            printf "\n" >>"$_tmpfile"
        done
    else
        for key in $keys; do
            value=$(printf "%s\n" "$json" | jq -r --arg k "$key" "try (.[\$k] | if type == \"object\" or type == \"array\" then tojson else tostring end) catch \"-\"")
            value=$(echo "$value" | tr '⋮' ' ')
            printf "%s⋮" "$value" >>"$_tmpfile"
        done
        printf "\n" >>"$_tmpfile"
    fi
    formatted=$(column -t -s '⋮' -o '  ' <"$_tmpfile")
    header=$(echo "$formatted" | head -1)
    data=$(echo "$formatted" | tail -n +2)
    header_trimmed=$(echo "$header" | sed 's/ *$//')
    max_length=${#header_trimmed}
    while IFS= read -r line; do
        trimmed_line=$(echo "$line" | sed 's/ *$//')
        curr_length=${#trimmed_line}
        if [ "$curr_length" -gt "$max_length" ]; then
            max_length=$curr_length
        fi
    done <<EOF
$(echo "$data")
EOF
    sep=$(printf "%${max_length}s" | tr ' ' '-')
    width=$(tput cols)
    {
        echo "$header"
        echo "$sep"
        echo "$data"
    } | while IFS= read -r line; do printf "%.${width}s\n" "$line"; done
    rm -f "$_tmpfile"
}

format_output() {
    output="${1:-text}"
    type="$2"
    if [ ! -t 0 ]; then
        input="$(cat)"
    else
        input=""
    fi
    case "$output" in
    json)
        printf "%s\n" "$input" | jq
        ;;
    yaml)
        printf "%s\n" "$input" | while read -r line; do
            echo "---"
            echo "$line" | json2yaml
        done
        ;;
    text)
        case "$type" in
        error)
            printf "${RED}%s${NC}\n" "$(echo "$input" | jq -r '.error')"
            return 1
            ;;
        *)
            format_json_table "$input" -
            ;;
        esac
        ;;
    *)
        printf '{"error":"unsupported output format %s"}\n' "$output" | format_output text error
        return 1
        ;;
    esac
}
