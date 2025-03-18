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
        fail "master output.json not found"
    fi
    echo "$_MASTER_OUTPUT_JSON"
}

get_master_ansible_private_hosts() {
    if [ -n "$_MASTER_ANSIBLE_PRIVATE_HOSTS" ]; then
        echo "$_MASTER_ANSIBLE_PRIVATE_HOSTS"
        return
    fi
    _MASTER_ANSIBLE_PRIVATE_HOSTS="$(get_master_output_json | jq -r '.node_private_ipv4s.value | to_entries[] | "\(.key) ansible_host=\(.value) access_ip=\(.value) ip=\(.value)"')"
    echo "$_MASTER_ANSIBLE_PRIVATE_HOSTS"
}

get_master_ssh_private_key() {
    if [ -n "$_MASTER_SSH_PRIVATE_KEY" ]; then
        echo "$_MASTER_SSH_PRIVATE_KEY"
        return
    fi
    _MASTER_SSH_PRIVATE_KEY="$(get_master_output_json | jq -r '.node_ssh_private_key.value // ""')"
    echo "$_MASTER_SSH_PRIVATE_KEY"
}

get_master_node_count() {
    if [ -n "$_MASTER_NODE_COUNT" ]; then
        echo "$_MASTER_NODE_COUNT"
        return
    fi
    _MASTER_NODE_COUNT="$(get_master_output_json | jq -r '.node_private_ipv4s.value | length')"
    echo "$_MASTER_NODE_COUNT"
}

get_master_private_ipv4s() {
    if [ -n "$_MASTER_PRIVATE_IPV4S" ]; then
        echo "$_MASTER_PRIVATE_IPV4S"
        return
    fi
    _MASTER_PRIVATE_IPV4S="$(get_master_output_json | jq -r '.node_private_ipv4s.value | .[] | @text')"
    echo "$_MASTER_PRIVATE_IPV4S"
}

get_master_public_ipv4s() {
    if [ -n "$_MASTER_PUBLIC_IPV4S" ]; then
        echo "$_MASTER_PUBLIC_IPV4S"
        return
    fi
    _MASTER_PUBLIC_IPV4S="$(get_master_output_json | jq -r '.node_public_ipv4s.value | .[] | @text')"
    echo "$_MASTER_PUBLIC_IPV4S"
}

get_supplementary_addresses() {
    if [ -n "$_SUPPLEMENTARY_ADDRESSES" ]; then
        echo "$_SUPPLEMENTARY_ADDRESSES"
        return
    fi
    _ENTRYPOINT="$(get_entrypoint)"
    _ENTRYPOINT_IPV4="$(get_entrypoint_ipv4)"
    _ENTRYPOINT_IPV6="$(get_entrypoint_ipv6)"
    _MASTER_PRIVATE_IPV4S="$(get_master_private_ipv4s)"
    _MASTER_PUBLIC_IPV4S="$(get_master_public_ipv4s)"
    _SUPPLEMENTARY_ADDRESSES="\"$_ENTRYPOINT\""
    if [ -n "$_ENTRYPOINT_IPV4" ]; then
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_ENTRYPOINT_IPV4\""
    fi
    if [ -n "$_ENTRYPOINT_IPV6" ]; then
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_ENTRYPOINT_IPV6\""
    fi
    for _IPV4 in $_MASTER_PRIVATE_IPV4S; do
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_IPV4\""
    done
    for _IPV4 in $_MASTER_PUBLIC_IPV4S; do
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_IPV4\""
    done
    echo "$_SUPPLEMENTARY_ADDRESSES"
}
