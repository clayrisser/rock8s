#!/bin/sh

_provider_yaml="  token: ref+env://HETZNER_TOKEN"

location="$(_dialog_menu "Select location" "nbg1" \
    nbg1 Nuremberg \
    fsn1 Falkenstein \
    hel1 Helsinki \
    ash Ashburn \
    hil Hillsboro)"

image="$(_dialog_menu "Select image" "debian-12" \
    debian-12 Debian_12 \
    ubuntu-24.04 Ubuntu_24.04)"

master_type="$(_dialog_menu "Select master node type" "cpx21" \
    cpx11 2vCPU/2GB \
    cpx21 3vCPU/4GB \
    cpx31 4vCPU/8GB \
    cpx41 8vCPU/16GB \
    cpx51 16vCPU/32GB \
    cax11 2vCPU/4GB_ARM \
    cax21 4vCPU/8GB_ARM \
    cax31 8vCPU/16GB_ARM \
    cax41 16vCPU/32GB_ARM \
    cx22 2vCPU/4GB_shared \
    cx32 4vCPU/8GB_shared \
    cx42 8vCPU/16GB_shared \
    cx52 16vCPU/32GB_shared)"
master_count="$(_prompt "master count" "1")"

worker_type="$(_dialog_menu "Select worker node type" "cpx31" \
    cpx11 2vCPU/2GB \
    cpx21 3vCPU/4GB \
    cpx31 4vCPU/8GB \
    cpx41 8vCPU/16GB \
    cpx51 16vCPU/32GB \
    cax11 2vCPU/4GB_ARM \
    cax21 4vCPU/8GB_ARM \
    cax31 8vCPU/16GB_ARM \
    cax41 16vCPU/32GB_ARM \
    cx22 2vCPU/4GB_shared \
    cx32 4vCPU/8GB_shared \
    cx42 8vCPU/16GB_shared \
    cx52 16vCPU/32GB_shared)"
worker_count="$(_prompt "worker count" "2")"
