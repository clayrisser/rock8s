#!/bin/sh

_provider_yaml="  access_key: ref+env://AWS_ACCESS_KEY_ID
  secret_key: ref+env://AWS_SECRET_ACCESS_KEY"

location="$(_dialog_menu "Select region" "eu-central-1" \
    us-east-1 N.Virginia \
    us-west-2 Oregon \
    eu-central-1 Frankfurt \
    eu-west-1 Ireland \
    ap-southeast-1 Singapore \
    ap-northeast-1 Tokyo)"

image="$(_dialog_menu "Select image" "debian-12" \
    debian-13 Debian_13 \
    debian-12 Debian_12 \
    debian-11 Debian_11 \
    ubuntu-25.10 Ubuntu_25.10_latest \
    ubuntu-24.04 Ubuntu_24.04_LTS \
    ubuntu-22.04 Ubuntu_22.04_LTS \
    ubuntu-20.04 Ubuntu_20.04_LTS)"

master_type="$(_dialog_menu "Select master instance type" "t3.medium" \
    t3.medium 2vCPU/4GB \
    t3.large 2vCPU/8GB \
    t3.xlarge 4vCPU/16GB \
    m5.large 2vCPU/8GB \
    m5.xlarge 4vCPU/16GB \
    m5.2xlarge 8vCPU/32GB \
    m6g.medium 1vCPU/4GB_ARM \
    m6g.large 2vCPU/8GB_ARM \
    m6g.xlarge 4vCPU/16GB_ARM \
    c5.large 2vCPU/4GB \
    c5.xlarge 4vCPU/8GB \
    c6g.large 2vCPU/4GB_ARM \
    c6g.xlarge 4vCPU/8GB_ARM \
    r5.large 2vCPU/16GB \
    r5.xlarge 4vCPU/32GB)"
worker_type="$(_dialog_menu "Select worker instance type" "t3.large" \
    t3.medium 2vCPU/4GB \
    t3.large 2vCPU/8GB \
    t3.xlarge 4vCPU/16GB \
    m5.large 2vCPU/8GB \
    m5.xlarge 4vCPU/16GB \
    m5.2xlarge 8vCPU/32GB \
    m6g.medium 1vCPU/4GB_ARM \
    m6g.large 2vCPU/8GB_ARM \
    m6g.xlarge 4vCPU/16GB_ARM \
    c5.large 2vCPU/4GB \
    c5.xlarge 4vCPU/8GB \
    c6g.large 2vCPU/4GB_ARM \
    c6g.xlarge 4vCPU/8GB_ARM \
    r5.large 2vCPU/16GB \
    r5.xlarge 4vCPU/32GB)"
worker_count="$(_prompt "worker count" "2")"
