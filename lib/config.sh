#!/bin/sh

set -e

get_cluster_dir() {
    if [ -n "$_CLUSTER_DIR" ]; then
        echo "$_CLUSTER_DIR"
        return
    fi
    if [ -z "$ROCK8S_CACHE_HOME" ]; then
        fail "ROCK8S_CACHE_HOME not set"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "ROCK8S_CLUSTER not set"
    fi
    _CLUSTER_DIR="$ROCK8S_CACHE_HOME/clusters/$ROCK8S_CLUSTER"
    echo "$_CLUSTER_DIR"
}

get_cluster_config_file() {
    if [ -n "$_CLUSTER_CONFIG_FILE" ]; then
        echo "$_CLUSTER_CONFIG_FILE"
        return
    fi
    if [ -n "$ROCK8S_CONFIG" ]; then
        if [ ! -f "$ROCK8S_CONFIG" ]; then
            fail "config file not found: $ROCK8S_CONFIG"
        fi
        _CLUSTER_CONFIG_FILE="$ROCK8S_CONFIG"
    elif [ -f "$(pwd)/rock8s.yaml" ]; then
        _CLUSTER_CONFIG_FILE="$(pwd)/rock8s.yaml"
    else
        fail "no config file found (use --config or create rock8s.yaml in current directory)"
    fi
    echo "$_CLUSTER_CONFIG_FILE"
}

# Load .env files for ref+env:// — never overrides variables already in the environment.
# Merge order (later file wins for a key among file-sourced values): $PWD/.env,
# <config-dir>/.env, path from ROCK8S_DOTENV (if set in the real environment).
_rock8s_merge_dotenv() {
    _cfg_rel="$1"
    _d="$(dirname "$_cfg_rel")"
    _b="$(basename "$_cfg_rel")"
    _root="$(CDPATH= cd -- "$_d" && pwd)"
    _cfg_abs="$_root/$_b"
    export ROCK8S__DOTENV_CONFIG_ABS="$_cfg_abs"
    eval "$(
        python3 <<'PY'
import os, shlex, re
from pathlib import Path

config_abs = os.environ["ROCK8S__DOTENV_CONFIG_ABS"]
paths = []
seen = set()


def add(p):
    if not p.is_file():
        return
    r = str(p.resolve())
    if r in seen:
        return
    seen.add(r)
    paths.append(p)


add(Path.cwd() / ".env")
add(Path(config_abs).parent / ".env")
ex = os.environ.get("ROCK8S_DOTENV", "").strip()
if ex:
    add(Path(ex).expanduser())


def parse_file(path):
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n\r")
            if not line.strip():
                continue
            if line.lstrip().startswith("#"):
                continue
            s = line.strip()
            if s.startswith("export "):
                s = s[7:].lstrip()
            if "=" not in s:
                continue
            key, _, val = s.partition("=")
            key = key.strip()
            val = val.strip()
            if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
                continue
            if len(val) >= 2 and val[0] == val[-1] and val[0] in "'\"":
                val = val[1:-1]
            yield key, val


merged = {}
for p in paths:
    for k, v in parse_file(p):
        if k in os.environ:
            continue
        merged[k] = v

for k, v in merged.items():
    print(f"export {k}={shlex.quote(v)}")
PY
    )"
    unset ROCK8S__DOTENV_CONFIG_ABS
}

get_config_json() {
    if [ -n "$_CONFIG_JSON" ]; then
        echo "$_CONFIG_JSON"
        return
    fi
    _CLUSTER_CONFIG_FILE="$(get_cluster_config_file)"
    _rock8s_merge_dotenv "$_CLUSTER_CONFIG_FILE"
    _CONFIG_JSON="$(yaml2json <"$_CLUSTER_CONFIG_FILE")"
    _CONFIG_JSON="$(echo "$_CONFIG_JSON" | resolve_refs)"
    echo "$_CONFIG_JSON"
}

get_config() {
    jq_filter="$1"
    default_value="$2"
    _CONFIG_JSON="$(get_config_json)"
    result="$(echo "$_CONFIG_JSON" | jq -r "$jq_filter" 2>/dev/null)"
    if [ -n "$result" ] && [ "$result" != "null" ]; then
        echo "$result"
        return
    fi
    echo "$default_value"
}

get_provider() {
    if [ -n "$_PROVIDER" ]; then
        echo "$_PROVIDER"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _PROVIDER="$(echo "$_CONFIG_JSON" | jq -r '.provider.type // ""')"
    if [ -z "$_PROVIDER" ]; then
        fail ".provider.type not found in config.yaml"
    fi
    echo "$_PROVIDER"
}

# Azure disallows several usernames including "admin"; VM image user must match k3sup/SSH.
get_node_ssh_user() {
    if [ -n "$_NODE_SSH_USER" ]; then
        echo "$_NODE_SSH_USER"
        return
    fi
    case "$(get_provider)" in
    azure) _NODE_SSH_USER="rock8s" ;;
    *) _NODE_SSH_USER="admin" ;;
    esac
    echo "$_NODE_SSH_USER"
}

get_entrypoint() {
    if [ -n "$_ENTRYPOINT" ]; then
        echo "$_ENTRYPOINT"
        return
    fi
    _CONFIG_JSON="$(get_config_json)"
    _ENTRYPOINT="$(echo "$_CONFIG_JSON" | jq -r '.network.entrypoint // ""')"
    if [ -z "$_ENTRYPOINT" ]; then
        fail ".network.entrypoint not found in config.yaml"
    fi
    echo "$_ENTRYPOINT"
}

get_entrypoint_ipv4() {
    if [ -n "$_ENTRYPOINT_IPV4" ]; then
        echo "$_ENTRYPOINT_IPV4"
        return
    fi
    _ENTRYPOINT_IPV4="$(_resolve_hostname "$(get_entrypoint)" "ipv4")"
    echo "$_ENTRYPOINT_IPV4"
}

get_addons_source_repo() {
    _CONFIG_JSON="$(get_config_json)"
    echo "$(echo "$_CONFIG_JSON" | jq -r '.addons.source.repo // ""')"
}

get_addons_source_version() {
    _CONFIG_JSON="$(get_config_json)"
    echo "$(echo "$_CONFIG_JSON" | jq -r '.addons.source.version // ""')"
}
