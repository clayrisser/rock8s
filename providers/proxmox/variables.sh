#!/bin/sh

set -e

export TF_VAR_proxmox_endpoint="$(get_config '.provider.endpoint // ""')"
if [ -z "$TF_VAR_proxmox_endpoint" ]; then
    fail "missing proxmox endpoint (set provider.endpoint in config)"
fi

export TF_VAR_proxmox_api_token="$(get_config '.provider.api_token // ""' "$PROXMOX_VE_API_TOKEN")"
if [ -z "$TF_VAR_proxmox_api_token" ]; then
    fail "missing proxmox API token (set provider.api_token in config or PROXMOX_VE_API_TOKEN env var)"
fi

export TF_VAR_proxmox_insecure="$(get_config '.provider.insecure // "true"')"
export TF_VAR_proxmox_node="$(get_config '.provider.node // ""' "pve")"
export TF_VAR_bridge="$(get_config '.provider.bridge // ""' "vmbr0")"
export TF_VAR_datastore_id="$(get_config '.provider.datastore // ""' "local-lvm")"
export TF_VAR_content_datastore_id="$(get_config '.provider.content_datastore // ""' "local")"

_DEFAULT_IMAGE="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
if [ -z "$TF_VAR_image" ] || [ "$TF_VAR_image" = "null" ]; then
    export TF_VAR_image="$(get_config '.provider.image // ""' "$_DEFAULT_IMAGE")"
fi
