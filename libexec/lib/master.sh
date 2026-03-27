#!/bin/sh

set -e

get_master_output_json_file() {
    if [ -n "$_MASTER_OUTPUT_JSON_FILE" ]; then
        echo "$_MASTER_OUTPUT_JSON_FILE"
        return
    fi
    _MASTER_OUTPUT_JSON_FILE="$(get_cluster_dir)/master/output.json"
    echo "$_MASTER_OUTPUT_JSON_FILE"
}

get_master_output_json() {
    if [ -n "$_MASTER_OUTPUT_JSON" ]; then
        echo "$_MASTER_OUTPUT_JSON"
        return
    fi
    _MASTER_OUTPUT_JSON_FILE="$(get_master_output_json_file)"
    if [ -f "$_MASTER_OUTPUT_JSON_FILE" ]; then
        _MASTER_OUTPUT_JSON="$(cat "$_MASTER_OUTPUT_JSON_FILE")"
    else
        _MASTER_OUTPUT_JSON='{}'
    fi
    echo "$_MASTER_OUTPUT_JSON"
}

get_master_ansible_private_hosts() {
    if [ -n "$_MASTER_ANSIBLE_PRIVATE_HOSTS" ]; then
        echo "$_MASTER_ANSIBLE_PRIVATE_HOSTS"
        return
    fi
    _MASTER_ANSIBLE_PRIVATE_HOSTS="$(get_master_output_json | jq -r '.node_private_ipv4s?.value // [] | to_entries[]? | "\(.key) ansible_host=\(.value) access_ip=\(.value) ip=\(.value)" // empty')"
    echo "$_MASTER_ANSIBLE_PRIVATE_HOSTS"
}

get_master_ssh_private_key() {
    if [ -n "$_MASTER_SSH_PRIVATE_KEY" ]; then
        echo "$_MASTER_SSH_PRIVATE_KEY"
        return
    fi
    _MASTER_SSH_PRIVATE_KEY="$(get_cluster_dir)/master/id_rsa"
    if [ ! -f "$_MASTER_SSH_PRIVATE_KEY" ]; then
        master_output="$(get_master_output_json)"
        pem="$(echo "$master_output" | jq -r '.node_ssh_private_key.value // ""')"
        if [ -n "$pem" ]; then
            printf '%s\n' "$pem" > "$_MASTER_SSH_PRIVATE_KEY"
            chmod 600 "$_MASTER_SSH_PRIVATE_KEY"
        else
            fail "master SSH private key not found"
        fi
    fi
    echo "$_MASTER_SSH_PRIVATE_KEY"
}

get_master_node_count() {
    if [ -n "$_MASTER_NODE_COUNT" ]; then
        echo "$_MASTER_NODE_COUNT"
        return
    fi
    _MASTER_NODE_COUNT="$(get_master_output_json | jq -r '.node_private_ipv4s?.value // [] | length // 0')"
    echo "$_MASTER_NODE_COUNT"
}

get_master_private_ipv4s() {
    if [ -n "$_MASTER_PRIVATE_IPV4S" ]; then
        echo "$_MASTER_PRIVATE_IPV4S"
        return
    fi
    _MASTER_PRIVATE_IPV4S="$(get_master_output_json | jq -r '.node_private_ipv4s?.value // [] | to_entries[]? | .value // empty')"
    echo "$_MASTER_PRIVATE_IPV4S"
}

get_master_architectures() {
    if [ -n "$_MASTER_ARCHITECTURES" ]; then
        echo "$_MASTER_ARCHITECTURES"
        return
    fi
    _MASTER_ARCHITECTURES="$(get_master_output_json | jq -r '.node_architectures?.value // {} | to_entries[]? | "\(.key)=\(.value)" // empty')"
    echo "$_MASTER_ARCHITECTURES"
}

get_supplementary_addresses() {
    if [ -n "$_SUPPLEMENTARY_ADDRESSES" ]; then
        echo "$_SUPPLEMENTARY_ADDRESSES"
        return
    fi
    entrypoint="$(get_entrypoint)"
    entrypoint_ipv4="$(get_entrypoint_ipv4)"
    master_private_ipv4s="$(get_master_private_ipv4s)"
    _SUPPLEMENTARY_ADDRESSES="\"$entrypoint\""
    if [ -n "$entrypoint_ipv4" ]; then
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$entrypoint_ipv4\""
    fi
    for ipv4 in $master_private_ipv4s; do
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$ipv4\""
    done
    echo "$_SUPPLEMENTARY_ADDRESSES"
}
