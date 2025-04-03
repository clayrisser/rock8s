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
    width=$(tput cols)
    {
        echo "$_HEADER"
        echo "$_SEP"
        echo "$_DATA"
    } | while IFS= read -r line;do printf "%.${width}s\n" "$line";done
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

format_size() {
    _SIZE=$1
    if [ $_SIZE -ge 1073741824 ]; then
        printf "%.2fG" "$(echo "scale=2; $_SIZE / 1073741824" | bc)"
    elif [ $_SIZE -ge 1048576 ]; then
        printf "%.2fM" "$(echo "scale=2; $_SIZE / 1048576" | bc)"
    else
        printf "%.2fK" "$(echo "scale=2; $_SIZE / 1024" | bc)"
    fi
}

show_progress() {
    _NAME=$1
    _CURRENT=$2
    _TOTAL=$3
    _RATE=$4
    _PERCENT=$5
    [ $_PERCENT -gt 100 ] && _PERCENT=99
    _BAR_WIDTH=20
    _FILLED=$((_PERCENT * _BAR_WIDTH / 100))
    _I=0
    _BAR=""
    while [ $_I -lt $_BAR_WIDTH ]; do
        if [ $_I -lt $_FILLED ]; then
            _BAR="${_BAR}█"
        else
            _BAR="${_BAR}░"
        fi
        _I=$((_I + 1))
    done
    printf "\033[2K\r%s %s %s/%s %s/s" "$_NAME" "$_BAR" "$(format_size $_CURRENT)" "$(format_size $_TOTAL)" "$(format_size $_RATE)" >&2
}
