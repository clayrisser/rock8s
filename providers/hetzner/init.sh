#!/bin/sh

_provider_yaml="  token: ref+env://HETZNER_TOKEN"

location="$(_dialog_menu "Select location" "nbg1" \
    nbg1 Nuremberg \
    fsn1 Falkenstein \
    hel1 Helsinki \
    ash Ashburn \
    hil Hillsboro)"

image="$(_dialog_menu "Select image" "debian-12" \
    debian-13 Debian_13 \
    debian-12 Debian_12 \
    ubuntu-25.10 Ubuntu_25.10_latest \
    ubuntu-24.04 Ubuntu_24.04_LTS \
    ubuntu-22.04 Ubuntu_22.04_LTS)"

master_type="$(_dialog_menu "Select master node type" "cpx32" \
    cx23 2vCPU_4GB_CX_shared \
    cx33 4vCPU_8GB_CX_shared \
    cx43 8vCPU_16GB_CX_shared \
    cx53 16vCPU_32GB_CX_shared \
    cpx22 2vCPU_4GB_CPX \
    cpx32 4vCPU_8GB_CPX \
    cpx42 8vCPU_16GB_CPX \
    cpx52 12vCPU_24GB_CPX \
    cpx62 16vCPU_32GB_CPX \
    ccx13 2vCPU_8GB_CCX \
    ccx23 4vCPU_16GB_CCX \
    ccx33 8vCPU_32GB_CCX \
    ccx43 16vCPU_64GB_CCX \
    ccx53 32vCPU_128GB_CCX \
    ccx63 48vCPU_192GB_CCX)"
worker_type="$(_dialog_menu "Select worker node type" "cpx42" \
    cx23 2vCPU_4GB_CX_shared \
    cx33 4vCPU_8GB_CX_shared \
    cx43 8vCPU_16GB_CX_shared \
    cx53 16vCPU_32GB_CX_shared \
    cpx22 2vCPU_4GB_CPX \
    cpx32 4vCPU_8GB_CPX \
    cpx42 8vCPU_16GB_CPX \
    cpx52 12vCPU_24GB_CPX \
    cpx62 16vCPU_32GB_CPX \
    ccx13 2vCPU_8GB_CCX \
    ccx23 4vCPU_16GB_CCX \
    ccx33 8vCPU_32GB_CCX \
    ccx43 16vCPU_64GB_CCX \
    ccx53 32vCPU_128GB_CCX \
    ccx63 48vCPU_192GB_CCX)"
worker_count="$(_prompt "worker count" "2")"
