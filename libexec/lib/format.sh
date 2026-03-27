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
    json="$1"
    keys="$2"
    [ -z "$json" ] && return
    temp_file=$(mktemp)
    type=$(printf "%s\n" "$json" | jq -r 'type')
    if [ "$type" = "object" ]; then
        key_count=$(printf "%s\n" "$json" | jq -r 'keys | length')
        if [ "$key_count" -eq 1 ]; then
            single_key=$(printf "%s\n" "$json" | jq -r 'keys[0]')
            single_value=$(printf "%s\n" "$json" | jq -r --arg k "$single_key" '.[$k] | if type == "object" or type == "array" then tojson else tostring end')
            echo "$single_value"
            rm -f "$temp_file"
            return
        fi
    fi
    if [ "$keys" = "-" ]; then
        if [ "$type" = "array" ]; then
            array_length=$(printf "%s\n" "$json" | jq 'length')
            if [ "$array_length" -eq 0 ]; then
                rm -f "$temp_file"
                return
            fi
            keys=$(printf "%s\n" "$json" | jq -r '.[0] | keys | join(" ")')
        else
            keys=$(printf "%s\n" "$json" | jq -r 'keys | join(" ")')
        fi
    fi
    for key in $keys; do
        printf "%s⋮" "$(echo "$key" | tr '[:lower:]' '[:upper:]')" >> "$temp_file"
    done
    printf "\n" >> "$temp_file"
    if [ "$type" = "array" ]; then
        length=$(printf "%s\n" "$json" | jq 'length')
        for i in $(seq 0 $((length - 1))); do
            for key in $keys; do
                value=$(printf "%s\n" "$json" | jq -r --arg k "$key" "try (.[${i}] | .[\$k] | if type == \"object\" or type == \"array\" then tojson else tostring end) catch \"-\"")
                value=$(echo "$value" | tr '⋮' ' ')
                printf "%s⋮" "$value" >> "$temp_file"
            done
            printf "\n" >> "$temp_file"
        done
    else
        for key in $keys; do
            value=$(printf "%s\n" "$json" | jq -r --arg k "$key" "try (.[\$k] | if type == \"object\" or type == \"array\" then tojson else tostring end) catch \"-\"")
            value=$(echo "$value" | tr '⋮' ' ')
            printf "%s⋮" "$value" >> "$temp_file"
        done
        printf "\n" >> "$temp_file"
    fi
    formatted=$(column -t -s '⋮' -o '  ' < "$temp_file")
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
    } | while IFS= read -r line;do printf "%.${width}s\n" "$line";done
    rm -f "$temp_file"
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
                success)
                    printf "${GREEN}%s${NC}\n" "$(echo "$input" | jq -r '.message')"
                    ;;
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

format_size() {
    size=$1
    if [ $size -ge 1073741824 ]; then
        printf "%.2fG" "$(echo "scale=2; $size / 1073741824" | bc)"
    elif [ $size -ge 1048576 ]; then
        printf "%.2fM" "$(echo "scale=2; $size / 1048576" | bc)"
    else
        printf "%.2fK" "$(echo "scale=2; $size / 1024" | bc)"
    fi
}

show_progress() {
    name=$1
    current=$2
    total=$3
    rate=$4
    percent=$5
    [ $percent -gt 100 ] && percent=99
    bar_width=20
    filled=$((percent * bar_width / 100))
    i=0
    bar=""
    while [ $i -lt $bar_width ]; do
        if [ $i -lt $filled ]; then
            bar="${bar}█"
        else
            bar="${bar}░"
        fi
        i=$((i + 1))
    done
    printf "\033[2K\r%s %s %s/%s %s/s" "$name" "$bar" "$(format_size $current)" "$(format_size $total)" "$(format_size $rate)" >&2
}
