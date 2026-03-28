#!/bin/sh

_provider_yaml="  subscription_id: ref+env://ARM_SUBSCRIPTION_ID
  client_id: ref+env://ARM_CLIENT_ID
  client_secret: ref+env://ARM_CLIENT_SECRET
  tenant_id: ref+env://ARM_TENANT_ID"

_lan_resource_group="$(_prompt "network resource group" "")"

location="$(_dialog_menu "Select region" "westeurope" \
    eastus East_US \
    westus2 West_US_2 \
    westeurope West_Europe \
    northeurope North_Europe \
    southeastasia Southeast_Asia \
    japaneast Japan_East)"

image="$(_dialog_menu "Select image" "debian-12" \
    debian-13 Debian_13 \
    debian-12 Debian_12 \
    debian-11 Debian_11 \
    ubuntu-25.10 Ubuntu_25.10_latest \
    ubuntu-24.04 Ubuntu_24.04_LTS \
    ubuntu-22.04 Ubuntu_22.04_LTS \
    ubuntu-20.04 Ubuntu_20.04_LTS)"

master_type="$(_dialog_menu "Select master VM size" "Standard_B2s" \
    Standard_B2s 2vCPU/4GB \
    Standard_B4ms 4vCPU/16GB \
    Standard_D2s_v5 2vCPU/8GB \
    Standard_D4s_v5 4vCPU/16GB \
    Standard_D8s_v5 8vCPU/32GB \
    Standard_D2ps_v5 2vCPU/8GB_ARM \
    Standard_D4ps_v5 4vCPU/16GB_ARM \
    Standard_E2s_v5 2vCPU/16GB \
    Standard_E4s_v5 4vCPU/32GB \
    Standard_F2s_v2 2vCPU/4GB \
    Standard_F4s_v2 4vCPU/8GB)"
worker_type="$(_dialog_menu "Select worker VM size" "Standard_B4ms" \
    Standard_B2s 2vCPU/4GB \
    Standard_B4ms 4vCPU/16GB \
    Standard_D2s_v5 2vCPU/8GB \
    Standard_D4s_v5 4vCPU/16GB \
    Standard_D8s_v5 8vCPU/32GB \
    Standard_D2ps_v5 2vCPU/8GB_ARM \
    Standard_D4ps_v5 4vCPU/16GB_ARM \
    Standard_E2s_v5 2vCPU/16GB \
    Standard_E4s_v5 4vCPU/32GB \
    Standard_F2s_v2 2vCPU/4GB \
    Standard_F4s_v2 4vCPU/8GB)"
worker_count="$(_prompt "worker count" "2")"
