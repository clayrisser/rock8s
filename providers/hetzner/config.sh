#!/bin/sh

set -e

. "$(dirname "$0")/../prompt.sh"
. "$(dirname "$0")/defaults.sh"

_IMAGE="$(prompt_enum "Select server image" "SERVER_IMAGE" "$DEFAULT_IMAGE" $AVAILABLE_IMAGES)"
_LOCATION="$(prompt_enum "Select location" "LOCATION" "$DEFAULT_LOCATION" $AVAILABLE_LOCATIONS)"
_NETWORK="$(prompt_text "Enter network name" "NETWORK_NAME" "$DEFAULT_NETWORK_NAME")"
_MASTER_TYPE="$(prompt_enum "Select master node type" "" "$DEFAULT_SERVER_TYPE" $AVAILABLE_SERVER_TYPES)"
_MASTER_COUNT="$(prompt_text "Enter number of master nodes" "" "$DEFAULT_MASTER_COUNT")"
_WORKER_TYPE="$(prompt_enum "Select worker node type" "" "$DEFAULT_SERVER_TYPE" $AVAILABLE_SERVER_TYPES)"
_WORKER_COUNT="$(prompt_text "Enter number of worker nodes" "" "$DEFAULT_WORKER_COUNT")"
_USE_USER_DATA="$(prompt_boolean "Do you want to provide user-data script" "USER_DATA" "0")"

cat << EOF
# Hetzner Cloud Configuration
# Generated by rock8s config tool

cluster_name: "$CLUSTER_NAME"
cluster_dir: "$CLUSTER_DIR"
server_image: "$_IMAGE"
location: "$_LOCATION"
network_name: "$_NETWORK"
master_groups:
  - type: $_MASTER_TYPE
    count: $_MASTER_COUNT
worker_groups:
  - type: $_WORKER_TYPE
    count: $_WORKER_COUNT
EOF

if [ "$_USE_USER_DATA" = "1" ]; then
    cat << 'EOF'
user_data: |
  #cloud-config
  package_update: true
  package_upgrade: true
EOF
fi
