#!/bin/sh

_cred_uri="$(_prompt "uri" "qemu:///system")"
_provider_yaml="  uri: $_cred_uri"

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
