#!/bin/sh

set -e

_ENSURED_SYSTEM=0

json2yaml() {
    /usr/bin/python3 -c 'import sys, yaml, json; print(yaml.dump(json.loads(sys.stdin.read()), default_flow_style=False))'
}

yaml2json() {
    /usr/bin/python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'
}

debug() {
    if [ "${ROCK8S_DEBUG:-0}" -eq 1 ]; then
        printf "${BLUE}rock8s[debug]:${NC} %s\n" "$1" >&2
    fi
}

log() {
    echo "${BLUE}rock8s:${NC} $1" >&2
}

success() {
    if [ "${_FORMAT:-text}" = "json" ]; then
        printf '{"message":"%s"}\n' "$1" >&2
    else
        printf '{"message":"%s"}\n' "$1" | format_output "${_FORMAT:-text}" success >&2
    fi
}

warn() {
    echo "${YELLOW}rock8s:${NC} $1" >&2
}

error() {
    if [ "${_FORMAT:-text}" = "json" ]; then
        printf "%s\n" "$1" | jq -R '{"error":.}' >&2
    else
        printf "%s\n" "$1" | jq -R '{"error":.}' | format_output "${_FORMAT:-text}" error
    fi
}

fail() {
    error "$1" >&2
    exit 1
}

ensure_system() {
    if [ "$_ENSURED_SYSTEM" -eq 1 ]; then
        return
    fi
    command -v tofu >/dev/null 2>&1 || {
        fail "tofu is not installed"
    }
    command -v ansible >/dev/null 2>&1 || {
        fail "ansible is not installed"
    }
    command -v kubectl >/dev/null 2>&1 || {
        fail "kubectl is not installed"
    }
    command -v jq >/dev/null 2>&1 || {
        fail "jq is not installed"
    }
    [ -x "/usr/bin/python3" ] || {
        fail "python3 is not installed"
    }
    _ENSURED_SYSTEM=1
}

check_dependencies() {
    missing=""
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || {
            [ -z "$missing" ] && missing="$cmd" || missing="$missing $cmd"
        }
    done
    [ -n "$missing" ] && {
        fail "missing required dependencies: $missing"
    }
}

parse_node_groups() {
    groups="$1"
    result="["
    first=1
    for group in $groups; do
        if [ "$first" = 1 ]; then
            first=0
        else
            result="$result,"
        fi
        type=$(echo "$group" | cut -d: -f1)
        count=$(echo "$group" | cut -d: -f2)
        opts="{}"
        if echo "$group" | grep -q ':.*:'; then
            raw_opts=$(echo "$group" | cut -d: -f3)
            opts="{"
            first_opt=1
            IFS=, read -r -a pairs <<EOF
$raw_opts
EOF
            for pair in "${pairs[@]}"; do
                key="${pair%%=*}"
                value="${pair#*=}"
                if [ "$first_opt" = 1 ]; then
                    first_opt=0
                else
                    opts="$opts,"
                fi
                opts="$opts\"$key\":\"$value\""
            done
            opts="$opts}"
        fi
        result="$result{\"type\":\"$type\",\"count\":$count,\"options\":$opts}"
    done
    result="$result]"
    echo "$result"
}

try() {
    i=0
    trap 'exit 130' INT
    while [ $i -lt $RETRIES ]; do
        i=$((i + 1))
        if [ $i -gt 1 ]; then
            echo "retry $i/$RETRIES"
            sleep 1
        fi
        if eval "$@"; then
            trap - INT
            return 0
        fi
    done
    trap - INT
    return 1
}
