#!/bin/sh

_cred_project="$(_prompt "project" "my-project")"
_provider_yaml="  project: $_cred_project"

location="$(_dialog_menu "Select region" "europe-west1" \
    us-central1 Iowa \
    us-east1 S.Carolina \
    us-west1 Oregon \
    europe-west1 Belgium \
    europe-west3 Frankfurt \
    asia-southeast1 Singapore \
    asia-northeast1 Tokyo)"

image="$(_dialog_menu "Select image" "debian-12" \
    debian-13 Debian_13 \
    debian-12 Debian_12 \
    debian-11 Debian_11 \
    ubuntu-25.10 Ubuntu_25.10_latest \
    ubuntu-24.04 Ubuntu_24.04_LTS \
    ubuntu-22.04 Ubuntu_22.04_LTS \
    ubuntu-20.04 Ubuntu_20.04_LTS)"

master_type="$(_dialog_menu "Select master machine type" "e2-medium" \
    e2-medium 2vCPU/4GB \
    e2-standard-2 2vCPU/8GB \
    e2-standard-4 4vCPU/16GB \
    e2-standard-8 8vCPU/32GB \
    n2-standard-2 2vCPU/8GB \
    n2-standard-4 4vCPU/16GB \
    n2-standard-8 8vCPU/32GB)"
worker_type="$(_dialog_menu "Select worker machine type" "e2-standard-2" \
    e2-medium 2vCPU/4GB \
    e2-standard-2 2vCPU/8GB \
    e2-standard-4 4vCPU/16GB \
    e2-standard-8 8vCPU/32GB \
    n2-standard-2 2vCPU/8GB \
    n2-standard-4 4vCPU/16GB \
    n2-standard-8 8vCPU/32GB)"
worker_count="$(_prompt "worker count" "2")"
