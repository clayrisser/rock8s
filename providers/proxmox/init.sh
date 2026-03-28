#!/bin/sh

_cred_endpoint="$(_prompt "endpoint URL" "https://10.0.0.2:8006/")"
_cred_node="$(_prompt "node name" "pve")"
_cred_insecure="$(_prompt "insecure TLS (true/false)" "true")"
_provider_yaml="  endpoint: $_cred_endpoint
  api_token: ref+env://PROXMOX_VE_API_TOKEN
  node: $_cred_node
  insecure: $_cred_insecure"

location=""
image=""
lan_subnet="$(_prompt "LAN IPv4 subnet" "10.0.1.0/24")"

master_type="$(_dialog_menu "Select master instance type" "medium" \
    small 1vCPU/2GB/20GB \
    medium 2vCPU/4GB/40GB \
    large 4vCPU/8GB/80GB \
    xlarge 8vCPU/16GB/160GB)"
worker_type="$(_dialog_menu "Select worker instance type" "large" \
    small 1vCPU/2GB/20GB \
    medium 2vCPU/4GB/40GB \
    large 4vCPU/8GB/80GB \
    xlarge 8vCPU/16GB/160GB)"
worker_count="$(_prompt "worker count" "2")"
