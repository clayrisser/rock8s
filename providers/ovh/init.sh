#!/bin/sh

_cred_tenant="$(_prompt "tenant_name" "")"
_cred_osuser="$(_prompt "openstack_user" "")"
_provider_yaml="  application_key: ref+env://OVH_APPLICATION_KEY
  application_secret: ref+env://OVH_APPLICATION_SECRET
  consumer_key: ref+env://OVH_CONSUMER_KEY
  tenant_name: $_cred_tenant
  openstack_user: $_cred_osuser
  openstack_password: ref+env://OS_PASSWORD"

location="$(_dialog_menu "Select region" "GRA7" \
    GRA7 Gravelines \
    BHS5 Beauharnois \
    SBG5 Strasbourg \
    WAW1 Warsaw \
    UK1 London \
    DE1 Frankfurt)"

image="$(_prompt "image" "Debian 12")"

master_type="$(_dialog_menu "Select master instance type" "b2-7" \
    b2-7 2vCPU/7GB \
    b2-15 4vCPU/15GB \
    b2-30 8vCPU/30GB \
    b2-60 16vCPU/60GB \
    b2-120 32vCPU/120GB)"
worker_type="$(_dialog_menu "Select worker instance type" "b2-15" \
    b2-7 2vCPU/7GB \
    b2-15 4vCPU/15GB \
    b2-30 8vCPU/30GB \
    b2-60 16vCPU/60GB \
    b2-120 32vCPU/120GB)"
worker_count="$(_prompt "worker count" "2")"
