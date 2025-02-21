#!/bin/sh

set -e

if [ "$HETZNER_TOKEN" = "" ]; then
    echo "missing HETZNER_TOKEN" >&2
    exit 1
fi

export TF_VAR_cluster_dir="$CLUSTER_DIR"
export TF_VAR_cluster_name="$CLUSTER_NAME"
export TF_VAR_hetzner_token="$HETZNER_TOKEN"
export TF_VAR_location="${LOCATION:=nbg1}"
export TF_VAR_master_groups="$MASTER_GROUPS"
export TF_VAR_network_name="${NETWORK_NAME:=private}"
export TF_VAR_server_image="${SERVER_IMAGE:=debian-12}"
export TF_VAR_user_data="$USER_DATA"
export TF_VAR_worker_groups="$WORKER_GROUPS"
