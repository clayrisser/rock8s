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
        printf "%s\n" "$1" | jq -R '{"error":.}'
    else
        printf "%s\n" "$1" | jq -R '{"error":.}' | _format_output "${_FORMAT:-text}" error >&2
    fi
}

_fail() {
    _error "$1"
    exit 1
}

json2yaml() {
    /usr/bin/python3 -c 'import sys, yaml, json; print(yaml.dump(json.loads(sys.stdin.read()), default_flow_style=False))'
}

yaml2json() {
    /usr/bin/python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'
}

_format_json_table() {
    _JSON="$1"
    _KEYS="$2"
    [ -z "$_JSON" ] && return 0
    if [ "$_KEYS" = "-" ]; then
        _KEYS="$(printf "%s\n" "$_JSON" | jq -r 'to_entries | .[].key' | tr '\n' ' ')"
    fi
    _COUNT="$(printf "%s\n" "$_JSON" | jq -s 'length')"
    if [ "$_COUNT" -eq 0 ]; then
        return 0
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
                echo "$line" | json2yaml
            done >&2
            ;;
        text)
            case "$_TYPE" in
                providers)
                    printf "%s\n" "$_INPUT" | jq -r '.[] | .name'
                    ;;
                search)
                    _format_json_table "$_INPUT" "repo name version path"
                    ;;
                ls)
                    _format_json_table "$_INPUT" "name environment status path"
                    ;;
                repo-list)
                    _format_json_table "$_INPUT" "path"
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

_ensure_system() {
    command -v terraform >/dev/null 2>&1 || {
        _fail "terraform is not installed"
    }
    command -v ansible >/dev/null 2>&1 || {
        _fail "ansible is not installed"
    }
    command -v kubectl >/dev/null 2>&1 || {
        _fail "kubectl is not installed"
    }
    command -v whiptail >/dev/null 2>&1 || {
        _fail "whiptail is not installed"
    }
    command -v jq >/dev/null 2>&1 || {
        _fail "jq is not installed"
    }
    [ -x "/usr/bin/python3" ] || {
        _fail "python3 is not installed"
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

_parse_node_groups() {
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

_get_cloud_init_config() {
    _SSH_PUBLIC_KEY="$1"
    cat <<EOF
#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "$_SSH_PUBLIC_KEY")
EOF
}

_calculate_metallb() {
    _SUBNET="$1"
    _SUBNET_PREFIX="$(echo "$_SUBNET" | cut -d'/' -f1)"
    _SUBNET_MASK="$(echo "$_SUBNET" | cut -d'/' -f2)"
    IFS='.'
    set -- $(echo "$_SUBNET_PREFIX")
    _OCTET1="$1"
    _OCTET2="$2"
    _OCTET3="$3"
    _OCTET4="$4"
    unset IFS
    _POW_VAL=$((32 - _SUBNET_MASK))
    _TOTAL_IPS=1
    _i=0
    while [ $_i -lt $_POW_VAL ]; do
        _TOTAL_IPS=$((_TOTAL_IPS * 2))
        _i=$((_i + 1))
    done
    _METALLB_COUNT="$((_TOTAL_IPS / 20))"
    [ "$_METALLB_COUNT" -lt 10 ] && _METALLB_COUNT=10
    [ "$_METALLB_COUNT" -gt 100 ] && _METALLB_COUNT=100
    if [ "$_METALLB_COUNT" -ge "$_TOTAL_IPS" ]; then
        _METALLB_COUNT="$((_TOTAL_IPS / 2))"
        [ "$_METALLB_COUNT" -lt 5 ] && _METALLB_COUNT=5
    fi
    _START_IP_NUM="$((_TOTAL_IPS - _METALLB_COUNT - 1))"
    _END_IP_NUM="$((_TOTAL_IPS - 2))"
    _START_OCTET4="$(( (_OCTET4 + _START_IP_NUM) % 256 ))"
    _START_OCTET3="$(( (_OCTET3 + ((_OCTET4 + _START_IP_NUM) / 256)) % 256 ))"
    _START_OCTET2="$(( (_OCTET2 + ((_OCTET3 + ((_OCTET4 + _START_IP_NUM) / 256)) / 256)) % 256 ))"
    _START_OCTET1="$(( _OCTET1 + ((_OCTET2 + ((_OCTET3 + ((_OCTET4 + _START_IP_NUM) / 256)) / 256)) / 256) ))"
    _END_OCTET4="$(( (_OCTET4 + _END_IP_NUM) % 256 ))"
    _END_OCTET3="$(( (_OCTET3 + ((_OCTET4 + _END_IP_NUM) / 256)) % 256 ))"
    _END_OCTET2="$(( (_OCTET2 + ((_OCTET3 + ((_OCTET4 + _END_IP_NUM) / 256)) / 256)) % 256 ))"
    _END_OCTET1="$(( _OCTET1 + ((_OCTET2 + ((_OCTET3 + ((_OCTET4 + _END_IP_NUM) / 256)) / 256)) / 256) ))"
    _START_IP="${_START_OCTET1}.${_START_OCTET2}.${_START_OCTET3}.${_START_OCTET4}"
    _END_IP="${_END_OCTET1}.${_END_OCTET2}.${_END_OCTET3}.${_END_OCTET4}"
    _METALLB_RANGE="${_START_IP}-${_END_IP}"
    if [ -z "$_METALLB_RANGE" ] || [ "$_START_OCTET1" -gt 255 ] || [ "$_END_OCTET1" -gt 255 ]; then
        if [ "$_SUBNET_MASK" -le "8" ]; then
            _NETWORK_BASE="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f1)"
            _METALLB_RANGE="${_NETWORK_BASE}.255.255.200-${_NETWORK_BASE}.255.255.254"
        elif [ "$_SUBNET_MASK" -le "16" ]; then
            _NETWORK_BASE="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f1-2)"
            _METALLB_RANGE="${_NETWORK_BASE}.255.200-${_NETWORK_BASE}.255.254"
        elif [ "$_SUBNET_MASK" -le "24" ]; then
            _NETWORK_BASE="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f1-3)"
            _METALLB_RANGE="${_NETWORK_BASE}.200-${_NETWORK_BASE}.254"
        else
            _IP_BASE="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f1-3)"
            _LAST_OCTET="$(echo "$_SUBNET_PREFIX" | cut -d'.' -f4)"
            _POW_VAL=$((32 - _SUBNET_MASK))
            _MAX_POW=1
            _i=0
            while [ $_i -lt $_POW_VAL ]; do
                _MAX_POW=$((_MAX_POW * 2))
                _i=$((_i + 1))
            done
            _MAX_IP="$((_MAX_POW + _LAST_OCTET - 2))"
            _MIN_IP="$((_MAX_IP - 10 > _LAST_OCTET ? _MAX_IP - 10 : _LAST_OCTET + 1))"
            _METALLB_RANGE="${_IP_BASE}.${_MIN_IP}-${_IP_BASE}.${_MAX_IP}"
        fi
    fi
    echo "$_METALLB_RANGE"
}

_calculate_next_ipv4() {
    _IP="$1"
    _INCREMENT="${2:-1}"
    if echo "$_IP" | grep -q '/'; then
        _IP="$(echo "$_IP" | cut -d'/' -f1)"
    fi
    if echo "$_IP" | grep -q '-'; then
        _IP="$(echo "$_IP" | cut -d'-' -f1)"
    fi
    _OCTET1="$(echo "$_IP" | cut -d'.' -f1)"
    _OCTET2="$(echo "$_IP" | cut -d'.' -f2)"
    _OCTET3="$(echo "$_IP" | cut -d'.' -f3)"
    _OCTET4="$(echo "$_IP" | cut -d'.' -f4)"
    _NEW_OCTET4=$((_OCTET4 + _INCREMENT))
    _NEW_OCTET3=$_OCTET3
    _NEW_OCTET2=$_OCTET2
    _NEW_OCTET1=$_OCTET1
    if [ $_NEW_OCTET4 -gt 255 ]; then
        _NEW_OCTET3=$((_OCTET3 + (_NEW_OCTET4 / 256)))
        _NEW_OCTET4=$((_NEW_OCTET4 % 256))
        if [ $_NEW_OCTET3 -gt 255 ]; then
            _NEW_OCTET2=$((_OCTET2 + (_NEW_OCTET3 / 256)))
            _NEW_OCTET3=$((_NEW_OCTET3 % 256))
            if [ $_NEW_OCTET2 -gt 255 ]; then
                _NEW_OCTET1=$((_OCTET1 + (_NEW_OCTET2 / 256)))
                _NEW_OCTET2=$((_NEW_OCTET2 % 256))
                if [ $_NEW_OCTET1 -gt 255 ]; then
                    _error "ip address overflow"
                    return 1
                fi
            fi
        fi
    fi
    echo "${_NEW_OCTET1}.${_NEW_OCTET2}.${_NEW_OCTET3}.${_NEW_OCTET4}"
}

_register_kubeconfig() {
    _KUBECONFIG_FILE="$1"
    _CLUSTER_NAME="$2"
    _TARGET_KUBECONFIG="${KUBECONFIG_PATH:-$HOME/.kube/config}"
    _NEW_CONTEXT="$(kubectl config get-contexts --kubeconfig="$_KUBECONFIG_FILE" -o name | head -n 1)"
    if [ -z "$_NEW_CONTEXT" ]; then
        _fail "context not found in kubeconfig file"
    fi
    _NEW_CLUSTER_NAME="$(kubectl config view --kubeconfig="$_KUBECONFIG_FILE" -o jsonpath='{.clusters[0].name}')"
    _NEW_USER_NAME="$(kubectl config view --kubeconfig="$_KUBECONFIG_FILE" -o jsonpath='{.users[0].name}')"
    mkdir -p "$(dirname "$_TARGET_KUBECONFIG")"
    if [ -f "$_TARGET_KUBECONFIG" ]; then
        cp "$_TARGET_KUBECONFIG" "$_TARGET_KUBECONFIG.bak"
    fi
    export KUBECONFIG="$_TARGET_KUBECONFIG:$_KUBECONFIG_FILE"
    _TMP_CONFIG="$(mktemp)"
    kubectl config view --merge --flatten > "$_TMP_CONFIG"
    mv "$_TMP_CONFIG" "$_TARGET_KUBECONFIG"
    export KUBECONFIG="$_TARGET_KUBECONFIG"
    kubectl config unset "contexts.$_CLUSTER_NAME" >/dev/null 2>&1 || true
    kubectl config unset "clusters.$_CLUSTER_NAME" >/dev/null 2>&1 || true
    kubectl config unset "users.$_CLUSTER_NAME" >/dev/null 2>&1 || true
    kubectl config rename-context "$_NEW_CONTEXT" "$_CLUSTER_NAME" >/dev/null
    kubectl config view --raw -o json | jq '
      .clusters[] |= if .name == "'"$_NEW_CLUSTER_NAME"'" then .name = "'"$_CLUSTER_NAME"'" else . end |
      .users[] |= if .name == "'"$_NEW_USER_NAME"'" then .name = "'"$_CLUSTER_NAME"'" else . end |
      .contexts[] |= if .name == "'"$_CLUSTER_NAME"'" then .context.cluster = "'"$_CLUSTER_NAME"'" | .context.user = "'"$_CLUSTER_NAME"'" else . end
    ' | json2yaml > "$_TARGET_KUBECONFIG.tmp"
    mv "$_TARGET_KUBECONFIG.tmp" "$_TARGET_KUBECONFIG"
    chmod 600 "$_TARGET_KUBECONFIG"
    kubectl config use-context "$_CLUSTER_NAME" >/dev/null
}
