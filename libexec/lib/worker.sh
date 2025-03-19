#!/bin/sh

set -e

get_worker_output_json_file() {
    if [ -n "$_WORKER_OUTPUT_JSON_FILE" ]; then
        echo "$_WORKER_OUTPUT_JSON_FILE"
        return
    fi
    _WORKER_OUTPUT_JSON_FILE="$(get_cluster_dir)/worker/output.json"
    echo "$_WORKER_OUTPUT_JSON_FILE"
}

get_worker_output_json() {
    if [ -n "$_WORKER_OUTPUT_JSON" ]; then
        echo "$_WORKER_OUTPUT_JSON"
        return
    fi
    _WORKER_OUTPUT_JSON_FILE="$(get_worker_output_json_file)"
    if [ -f "$_WORKER_OUTPUT_JSON_FILE" ]; then
        _WORKER_OUTPUT_JSON="$(cat "$_WORKER_OUTPUT_JSON_FILE")"
    else
        _WORKER_OUTPUT_JSON='{}'
    fi
    echo "$_WORKER_OUTPUT_JSON"
}

get_worker_ansible_private_hosts() {
    if [ -n "$_WORKER_ANSIBLE_PRIVATE_HOSTS" ]; then
        echo "$_WORKER_ANSIBLE_PRIVATE_HOSTS"
        return
    fi
    _WORKER_ANSIBLE_PRIVATE_HOSTS="$(get_worker_output_json | jq -r '.node_private_ipv4s.value | to_entries[]? | "\(.key) ansible_host=\(.value) access_ip=\(.value) ip=\(.value)" // empty')"
    echo "$_WORKER_ANSIBLE_PRIVATE_HOSTS"
}

get_worker_ssh_private_key() {
    if [ -n "$_WORKER_SSH_PRIVATE_KEY" ]; then
        echo "$_WORKER_SSH_PRIVATE_KEY"
        return
    fi
    _WORKER_SSH_PRIVATE_KEY="$(get_worker_output_json | jq -r '.node_ssh_private_key.value // ""')"
    echo "$_WORKER_SSH_PRIVATE_KEY"
}

get_worker_node_count() {
    if [ -n "$_WORKER_NODE_COUNT" ]; then
        echo "$_WORKER_NODE_COUNT"
        return
    fi
    _WORKER_NODE_COUNT="$(get_worker_output_json | jq -r '.node_private_ipv4s.value | length // 0')"
    echo "$_WORKER_NODE_COUNT"
}

get_worker_private_ipv4s() {
    if [ -n "$_WORKER_PRIVATE_IPV4S" ]; then
        echo "$_WORKER_PRIVATE_IPV4S"
        return
    fi
    _WORKER_PRIVATE_IPV4S="$(get_worker_output_json | jq -r '.node_private_ipv4s.value | to_entries[]? | .value // empty')"
    echo "$_WORKER_PRIVATE_IPV4S"
}

get_worker_public_ipv4s() {
    if [ -n "$_WORKER_PUBLIC_IPV4S" ]; then
        echo "$_WORKER_PUBLIC_IPV4S"
        return
    fi
    _WORKER_PUBLIC_IPV4S="$(get_worker_output_json | jq -r '.node_public_ipv4s.value | to_entries[]? | .value // empty')"
    echo "$_WORKER_PUBLIC_IPV4S"
}
