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
    error "$1"
    exit 1
}

ensure_system() {
    if [ "$_ENSURED_SYSTEM" -eq 1 ]; then
        return
    fi
    command -v terraform >/dev/null 2>&1 || {
        fail "terraform is not installed"
    }
    command -v ansible >/dev/null 2>&1 || {
        fail "ansible is not installed"
    }
    command -v kubectl >/dev/null 2>&1 || {
        fail "kubectl is not installed"
    }
    command -v whiptail >/dev/null 2>&1 || {
        fail "whiptail is not installed"
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
    _MISSING=""
    for _CMD in "$@"; do
        command -v "$_CMD" >/dev/null 2>&1 || {
            [ -z "$_MISSING" ] && _MISSING="$_CMD" || _MISSING="$_MISSING $_CMD"
        }
    done
    [ -n "$_MISSING" ] && {
        fail "missing required dependencies: $_MISSING"
    }
}

parse_node_groups() {
    _GROUPS="$1"
    _RESULT="["
    _FIRST=1
    for group in $_GROUPS; do
        if [ "$_FIRST" = 1 ]; then
            _FIRST=0
        else
            _RESULT="$_RESULT,"
        fi
        _TYPE=$(echo "$group" | cut -d: -f1)
        _COUNT=$(echo "$group" | cut -d: -f2)
        _OPTS="{}"
        if echo "$group" | grep -q ':.*:'; then
            _RAW_OPTS=$(echo "$group" | cut -d: -f3)
            _OPTS="{"
            _FIRST_OPT=1
            IFS=, read -r -a pairs <<EOF
$_RAW_OPTS
EOF
            for pair in "${pairs[@]}"; do
                key="${pair%%=*}"
                value="${pair#*=}"
                if [ "$_FIRST_OPT" = 1 ]; then
                    _FIRST_OPT=0
                else
                    _OPTS="$_OPTS,"
                fi
                _OPTS="$_OPTS\"$key\":\"$value\""
            done
            _OPTS="$_OPTS}"
        fi
        _RESULT="$_RESULT{\"type\":\"$_TYPE\",\"count\":$_COUNT,\"options\":$_OPTS}"
    done
    _RESULT="$_RESULT]"
    echo "$_RESULT"
}
