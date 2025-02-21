#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

_debug() {
    if [ "${ROCK8S_DEBUG:-0}" -eq 1 ]; then
        printf "${BLUE}rock8s[debug]:${NC} %s\n" "$1" >&2
    fi
}

_log() {
    echo "${BLUE}rock8s:${NC} $1" >&2
}

_success() {
    if [ "${_FORMAT:-text}" = "json" ]; then
        printf '{"message":"%s"}\n' "$1"
    else
        printf '{"message":"%s"}\n' "$1" | _format_output "${_FORMAT:-text}" success >&2
    fi
}

_warn() {
    echo "${YELLOW}rock8s:${NC} $1" >&2
}

_error() {
    if [ "${_FORMAT:-text}" = "json" ]; then
        printf '{"error":"%s"}\n' "$1"
    else
        printf '{"error":"%s"}\n' "$1" | _format_output "${_FORMAT:-text}" error >&2
    fi
}

_fail() {
    _error "$1"
    exit 1
}

_format_output() {
    _FORMAT="${1:-text}"
    _TYPE="$2"
    if [ ! -t 0 ]; then
        _INPUT="$(cat)"
    else
        _INPUT=""
    fi
    case "$_FORMAT" in
        json)
            printf "%s\n" "$_INPUT"
            ;;
        yaml)
            printf "%s\n" "$_INPUT" | while read -r line; do
                echo "---"
                echo "$line" | _json2yaml
            done >&2
            ;;
        text)
            case "$_TYPE" in
                providers)
                    _format_json_table "$_INPUT" "name type region status"
                    ;;
                kubespray)
                    _format_json_table "$_INPUT" "name version status nodes"
                    ;;
                cluster)
                    _format_json_table "$_INPUT" "name type status"
                    ;;
                success)
                    printf "${GREEN}%s${NC}\n" "$(echo "$_INPUT" | jq -r '.message')"
                    ;;
                error)
                    printf "${RED}%s${NC}\n" "$(echo "$_INPUT" | jq -r '.error')"
                    return 1
                    ;;
                *)
                    _format_json_table "$_INPUT" -
                    ;;
            esac
            ;;
        *)
            printf '{"error":"unsupported output format: %s"}\n' "$_FORMAT" | _format_output text error
            return 1
            ;;
    esac
}

_json2yaml() {
    perl -MJSON::PP -MYAML -e '
        my $json = do { local $/; <STDIN> };
        my $data = decode_json($json);
        print Dump($data);
    '
}

_format_json_table() {
    _JSON="$1"
    _KEYS="$2"
    [ -z "$_JSON" ] && return 0
    if [ "$_KEYS" = "-" ]; then
        _KEYS="$(printf "%s\n" "$_JSON" | jq -r 'to_entries | .[].key' | tr '\n' ' ')"
    fi
    _COUNT="$(printf "%s\n" "$_JSON" | jq -s 'length')"
    if [ "$_COUNT" -eq 1 ]; then
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
            printf "%s\n" "$_JSON" | jq -s '.' | jq -r "$_JQ_FILTER"
        ) | sed 's/^ *//' | tr '\t' ' ' | column -t
    fi
}

_validate_cluster_name() {
    _NAME="$1"
    echo "$_NAME" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$' || {
        _fail "invalid cluster name (must contain only lowercase letters, numbers, and hyphens, and must start and end with an alphanumeric character)"
    }
}

_get_cluster_dir() {
    _NAME="$1"
    echo "$ROCK8S_STATE_ROOT/clusters/$_NAME"
}

_ensure_terraform() {
    command -v terraform >/dev/null 2>&1 || {
        _fail "terraform is not installed"
    }
}

_ensure_ansible() {
    command -v ansible >/dev/null 2>&1 || {
        _fail "ansible is not installed"
    }
}

_ensure_kubectl() {
    command -v kubectl >/dev/null 2>&1 || {
        _fail "kubectl is not installed"
    }
}

_validate_kubeconfig() {
    _KUBECONFIG="$1"
    [ -f "$_KUBECONFIG" ] || {
        _fail "kubeconfig not found: $_KUBECONFIG"
    }
}

_check_dependencies() {
    _MISSING=""
    for _CMD in "$@"; do
        command -v "$_CMD" >/dev/null 2>&1 || {
            [ -z "$_MISSING" ] && _MISSING="$_CMD" || _MISSING="$_MISSING $_CMD"
        }
    done
    [ -n "$_MISSING" ] && {
        _fail "missing required dependencies: $_MISSING"
    }
}

_validate_environment() {
    _ensure_config_dirs
    _check_dependencies curl tar git jq perl
}

_ensure_config_dirs() {
    mkdir -p "$ROCK8S_STATE_ROOT"
    mkdir -p "$ROCK8S_STATE_ROOT/clusters"
    for _PATH in $(echo "$ROCK8S_CONFIG_PATHS" | tr ':' ' '); do
        mkdir -p "$_PATH"
    done
}
