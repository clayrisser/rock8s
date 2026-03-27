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

get_worker_ssh_private_key() {
    if [ -n "$_WORKER_SSH_PRIVATE_KEY" ]; then
        echo "$_WORKER_SSH_PRIVATE_KEY"
        return
    fi
    _WORKER_SSH_PRIVATE_KEY="$(get_cluster_dir)/worker/id_rsa"
    if [ ! -f "$_WORKER_SSH_PRIVATE_KEY" ]; then
        worker_output="$(get_worker_output_json)"
        pem="$(echo "$worker_output" | jq -r '.node_ssh_private_key.value // ""')"
        if [ -n "$pem" ]; then
            printf '%s\n' "$pem" >"$_WORKER_SSH_PRIVATE_KEY"
            chmod 600 "$_WORKER_SSH_PRIVATE_KEY"
        else
            fail "worker SSH private key not found"
        fi
    fi
    echo "$_WORKER_SSH_PRIVATE_KEY"
}

get_worker_private_ipv4s() {
    if [ -n "$_WORKER_PRIVATE_IPV4S" ]; then
        echo "$_WORKER_PRIVATE_IPV4S"
        return
    fi
    _WORKER_PRIVATE_IPV4S="$(get_worker_output_json | jq -r '.node_private_ipv4s?.value // [] | to_entries[]? | .value // empty')"
    echo "$_WORKER_PRIVATE_IPV4S"
}
