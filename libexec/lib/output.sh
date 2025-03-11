#!/bin/sh

_get_master_output_json() {
    if [ -n "$_MASTER_OUTPUT_JSON" ]; then
        echo "$_MASTER_OUTPUT_JSON"
        return 0
    fi
    _CLUSTER_DIR="$(_get_cluster_dir)"
    if [ -f "$_CLUSTER_DIR/master/output.json" ]; then
        _MASTER_OUTPUT_JSON="$(cat "$_CLUSTER_DIR/master/output.json")"
    else
        _fail "master output.json not found"
    fi
    echo "$_MASTER_OUTPUT_JSON"
}

_get_worker_output_json() {
    if [ -n "$_WORKER_OUTPUT_JSON" ]; then
        echo "$_WORKER_OUTPUT_JSON"
        return 0
    fi
    _CLUSTER_DIR="$(_get_cluster_dir)"
    if [ -f "$_CLUSTER_DIR/worker/output.json" ]; then
        _WORKER_OUTPUT_JSON="$(cat "$_CLUSTER_DIR/worker/output.json")"
    else
        _fail "worker output.json not found"
    fi
    echo "$_WORKER_OUTPUT_JSON"
}

# _get_node_output_json() {
#     _NODE_TYPE="$1"
#     _cache_var="_CACHE_NODE_${_NODE_TYPE}_OUTPUT"
#     eval "_cached=\$$_cache_var"
#     if [ -n "$_cached" ]; then
#         echo "$_cached"
#         return 0
#     fi
    
#     _CLUSTER_DIR="$(_get_cluster_dir "$_TENANT" "$_CLUSTER")"
#     _output_file="$_CLUSTER_DIR/$_NODE_TYPE/output.json"
#     if [ ! -f "$_output_file" ]; then
#         _fail "$_NODE_TYPE output.json not found"
#     fi
#     eval "$_cache_var='$(cat "$_output_file")'"
#     eval "echo \$$_cache_var"
# }

# _get_node_output_file() {
#     _CLUSTER_DIR="$1"
#     _NODE_TYPE="$2"
#     echo "$_CLUSTER_DIR/$_NODE_TYPE/output.json"
# }

# _get_node_private_ips() {
#     _NODE_TYPE="$1"
#     jq -r '.node_private_ips.value | to_entries[] | "\(.key) ansible_host=\(.value)"' "$(_get_node_output_json "$_NODE_TYPE")"
# }

# _get_node_ssh_key() {
#     _NODE_TYPE="$1"
#     jq -r '.node_ssh_private_key.value' "$(_get_node_output_json "$_NODE_TYPE")"
# }

# _get_node_master_ipv4() {
#     _NODE_TYPE="$1"
#     jq -r '.node_private_ips.value | .[keys[0]]' "$(_get_node_output_json "$_NODE_TYPE")"
# }

# _get_cluster_node_ssh_key() {
#     _NODE_OUTPUT_JSON="$1"
#     jq -r '.node_ssh_private_key.value // ""' "$_NODE_OUTPUT_JSON"
# }

# _get_cluster_node_count() {
#     _NODE_OUTPUT_JSON="$1"
#     jq -r '.node_ips.value | length' "$_NODE_OUTPUT_JSON"
# }

# _get_cluster_node_ips() {
#     _NODE_OUTPUT_JSON="$1"
#     jq -r '.node_ips.value | to_entries[] | .key' "$_NODE_OUTPUT_JSON"
# }

# _get_cluster_node_output_json() {
#     _NODE_DIR="$1"
#     _output_json="$_NODE_DIR/output.json"
#     if [ ! -f "$_output_json" ]; then
#         _fail "output.json not found at $_output_json"
#     fi
#     echo "$_output_json"
# } 
