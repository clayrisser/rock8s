#!/bin/sh

_cred_endpoint="$(_prompt "endpoint URL" "https://10.0.0.2:8006/")"
_cred_node="$(_prompt "node name" "pve")"
_cred_insecure="$(_prompt "insecure TLS (true/false)" "true")"
_provider_yaml="  endpoint: $_cred_endpoint
  api_token: ref+env://PROXMOX_VE_API_TOKEN
  node: $_cred_node
  insecure: $_cred_insecure"

location=""
lan_subnet="$(_prompt "LAN IPv4 subnet" "10.0.1.0/24")"

_img_pick="$(_dialog_menu "Select cloud image" "deb12amd" \
    deb13amd Debian_13_trixie \
    deb12amd Debian_12_bookworm \
    u24amd Ubuntu_24.04_LTS \
    u25amd Ubuntu_25.10)"
case "$_img_pick" in
deb13amd) image="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2" ;;
deb12amd) image="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2" ;;
u24amd) image="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img" ;;
u25amd) image="https://cloud-images.ubuntu.com/releases/25.10/release/ubuntu-25.10-server-cloudimg-amd64.img" ;;
*) image="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2" ;;
esac

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
