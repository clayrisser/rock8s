#!/bin/sh

set -e

format_table() {
    awk 'BEGIN{FS="|"; OFS="\t"}
    {
        for(i=1; i<=NF; i++) {
            if(NR==1) header[i] = $i
            max_len[i] = max_len[i] < length($i) ? length($i) : max_len[i]
        }
    }
    END{
        total_width = 0
        for(i=1; i<=NF; i++) {
            printf "%-*s ", max_len[i]+2, header[i]
            total_width += max_len[i] + 3
        }
        printf "\n"
        for(i=1; i<total_width; i++) printf "-"
        printf "\n"
        for(row=2; row<=NR; row++) {
            split(line[row], cells, FS)
            for(i=1; i<=NF; i++) printf "%-*s ", max_len[i]+2, cells[i]
            printf "\n"
        }
    }'
}

format_json_table() {
    _JSON="$1"
    _KEYS="$2"
    [ -z "$_JSON" ] && return
    _TEMP_FILE=$(mktemp)
    _TYPE=$(printf "%s\n" "$_JSON" | jq -r 'type')
    if [ "$_TYPE" = "object" ]; then
        _KEY_COUNT=$(printf "%s\n" "$_JSON" | jq -r 'keys | length')
        if [ "$_KEY_COUNT" -eq 1 ]; then
            _SINGLE_KEY=$(printf "%s\n" "$_JSON" | jq -r 'keys[0]')
            _SINGLE_VALUE=$(printf "%s\n" "$_JSON" | jq -r --arg k "$_SINGLE_KEY" '.[$k] | if type == "object" or type == "array" then tojson else tostring end')
            echo "$_SINGLE_VALUE"
            rm -f "$_TEMP_FILE"
            return
        fi
    fi
    if [ "$_KEYS" = "-" ]; then
        if [ "$_TYPE" = "array" ]; then
            _ARRAY_LENGTH=$(printf "%s\n" "$_JSON" | jq 'length')
            if [ "$_ARRAY_LENGTH" -eq 0 ]; then
                rm -f "$_TEMP_FILE"
                return
            fi
            _KEYS=$(printf "%s\n" "$_JSON" | jq -r '.[0] | keys | join(" ")')
        else
            _KEYS=$(printf "%s\n" "$_JSON" | jq -r 'keys | join(" ")')
        fi
    fi
    for _KEY in $_KEYS; do
        printf "%s⋮" "$(echo "$_KEY" | tr '[:lower:]' '[:upper:]')" >> "$_TEMP_FILE"
    done
    printf "\n" >> "$_TEMP_FILE"
    if [ "$_TYPE" = "array" ]; then
        _LENGTH=$(printf "%s\n" "$_JSON" | jq 'length')
        for i in $(seq 0 $((_LENGTH - 1))); do
            for _KEY in $_KEYS; do
                _VALUE=$(printf "%s\n" "$_JSON" | jq -r --arg k "$_KEY" "try (.[${i}] | .[\$k] | if type == \"object\" or type == \"array\" then tojson else tostring end) catch \"-\"")
                _VALUE=$(echo "$_VALUE" | tr '⋮' ' ')
                printf "%s⋮" "$_VALUE" >> "$_TEMP_FILE"
            done
            printf "\n" >> "$_TEMP_FILE"
        done
    else
        for _KEY in $_KEYS; do
            _VALUE=$(printf "%s\n" "$_JSON" | jq -r --arg k "$_KEY" "try (.[\$k] | if type == \"object\" or type == \"array\" then tojson else tostring end) catch \"-\"")
            _VALUE=$(echo "$_VALUE" | tr '⋮' ' ')
            printf "%s⋮" "$_VALUE" >> "$_TEMP_FILE"
        done
        printf "\n" >> "$_TEMP_FILE"
    fi
    _FORMATTED=$(column -t -s '⋮' -o '  ' < "$_TEMP_FILE")
    _HEADER=$(echo "$_FORMATTED" | head -1)
    _DATA=$(echo "$_FORMATTED" | tail -n +2)
    _HEADER_TRIMMED=$(echo "$_HEADER" | sed 's/ *$//')
    _MAX_LENGTH=${#_HEADER_TRIMMED}
    while IFS= read -r line; do
        trimmed_line=$(echo "$line" | sed 's/ *$//')
        curr_length=${#trimmed_line}
        if [ "$curr_length" -gt "$_MAX_LENGTH" ]; then
            _MAX_LENGTH=$curr_length
        fi
    done <<EOF
$(echo "$_DATA")
EOF
    _SEP=$(printf "%${_MAX_LENGTH}s" | tr ' ' '-')
    echo "$_HEADER"
    echo "$_SEP"
    echo "$_DATA"
    rm -f "$_TEMP_FILE"
}

format_output() {
    _OUTPUT="${1:-text}"
    _TYPE="$2"
    if [ ! -t 0 ]; then
        _INPUT="$(cat)"
    else
        _INPUT=""
    fi
    case "$_OUTPUT" in
        json)
            printf "%s\n" "$_INPUT" | jq
            ;;
        yaml)
            printf "%s\n" "$_INPUT" | while read -r line; do
                echo "---"
                echo "$line" | json2yaml
            done
            ;;
        text)
            case "$_TYPE" in
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
            printf '{"error":"unsupported output format %s"}\n' "$_OUTPUT" | format_output text error
            return 1
            ;;
    esac
}
