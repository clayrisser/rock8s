#!/bin/sh

set -e

export TF_VAR_cluster_entrypoint="$CLUSTER_ENTRYPOINT"
export TF_VAR_cluster_name="$CLUSTER_NAME"
export TF_VAR_data_dir="$DATA_DIR"
export TF_VAR_hetzner_token="$HETZNER_TOKEN"
export TF_VAR_location="$HETZNER_LOCATION"
export TF_VAR_master_count="$HETZNER_MASTER_COUNT"
export TF_VAR_network_ip_range="$HETZNER_NETWORK_IP_RANGE"
export TF_VAR_network_zone="$HETZNER_NETWORK_ZONE"
export TF_VAR_node_count="$HETZNER_NODE_COUNT"
export TF_VAR_provider_dir="$PROVIDER_DIR"
export TF_VAR_server_image="$HETZNER_SERVER_IMAGE"
export TF_VAR_server_type="$HETZNER_SERVER_TYPE"
export TF_VAR_subnet_ip_range="$HETZNER_SUBNET_IP_RANGE"
