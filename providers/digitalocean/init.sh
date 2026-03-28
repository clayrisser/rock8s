#!/bin/sh

_provider_yaml="  token: ref+env://DIGITALOCEAN_TOKEN"

location="$(_dialog_menu "Select region" "fra1" \
    nyc1 New_York_1 \
    nyc3 New_York_3 \
    sfo3 San_Francisco \
    ams3 Amsterdam \
    fra1 Frankfurt \
    lon1 London \
    sgp1 Singapore \
    blr1 Bangalore \
    syd1 Sydney)"

image="$(_dialog_menu "Select image" "debian-12-x64" \
    debian-12-x64 Debian_12 \
    ubuntu-24-04-x64 Ubuntu_24.04)"

master_type="$(_dialog_menu "Select master droplet size" "s-2vcpu-4gb" \
    s-2vcpu-4gb 2vCPU/4GB \
    s-4vcpu-8gb 4vCPU/8GB \
    s-8vcpu-16gb 8vCPU/16GB)"
master_count="$(_prompt "master count" "1")"

worker_type="$(_dialog_menu "Select worker droplet size" "s-4vcpu-8gb" \
    s-2vcpu-4gb 2vCPU/4GB \
    s-4vcpu-8gb 4vCPU/8GB \
    s-8vcpu-16gb 8vCPU/16GB)"
worker_count="$(_prompt "worker count" "2")"
