#!/bin/sh

set -e

_ENSURED_SYSTEM=0

json2yaml() {
    /usr/bin/python3 -c 'import sys, yaml, json; print(yaml.dump(json.loads(sys.stdin.read()), default_flow_style=False))'
}

yaml2json() {
    /usr/bin/python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'
}

log() {
    echo "${BLUE}rock8s:${NC} $1" >&2
}

warn() {
    echo "${YELLOW}rock8s:${NC} $1" >&2
}

error() {
    if [ "${ROCK8S_OUTPUT:-text}" = "json" ]; then
        printf "%s\n" "$1" | jq -R '{"error":.}' >&2
    else
        printf "%s\n" "$1" | jq -R '{"error":.}' | format_output "${ROCK8S_OUTPUT:-text}" error
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
