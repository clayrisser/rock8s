#!/bin/sh

_provider_yaml="  api_key: ref+env://VULTR_API_KEY"

location="$(_dialog_menu "Select region" "fra" \
    ewr New_Jersey \
    ord Chicago \
    dfw Dallas \
    sea Seattle \
    lax Los_Angeles \
    fra Frankfurt \
    ams Amsterdam \
    lhr London \
    sgp Singapore \
    nrt Tokyo \
    syd Sydney)"

image="$(_dialog_menu "Select image" "debian-12" \
    debian-13 Debian_13 \
    debian-12 Debian_12 \
    debian-11 Debian_11 \
    ubuntu-25.10 Ubuntu_25.10_latest \
    ubuntu-24.04 Ubuntu_24.04_LTS \
    ubuntu-22.04 Ubuntu_22.04_LTS \
    ubuntu-20.04 Ubuntu_20.04_LTS)"

master_type="$(_dialog_menu "Select master instance type" "vc2-2c-4gb" \
    vc2-1c-2gb 1vCPU/2GB \
    vc2-2c-4gb 2vCPU/4GB \
    vc2-4c-8gb 4vCPU/8GB \
    vc2-6c-16gb 6vCPU/16GB \
    vc2-8c-32gb 8vCPU/32GB)"
worker_type="$(_dialog_menu "Select worker instance type" "vc2-4c-8gb" \
    vc2-1c-2gb 1vCPU/2GB \
    vc2-2c-4gb 2vCPU/4GB \
    vc2-4c-8gb 4vCPU/8GB \
    vc2-6c-16gb 6vCPU/16GB \
    vc2-8c-32gb 8vCPU/32GB)"
worker_count="$(_prompt "worker count" "2")"
