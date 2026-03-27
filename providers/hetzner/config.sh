#!/bin/sh

set -e

_AVAILABLE_LOCATIONS="
nbg1
fsn1
hel1
sin
hil
ash"

_AVAILABLE_SERVER_TYPES="
cpx11
cpx21
cpx31
cpx41
cpx51
cax11
cax21
cax31
cax41
ccx13
ccx23
ccx33
ccx43
ccx53
ccx63
cx22
cx32
cx42
cx52"

_DEFAULT_LOCATION="nbg1"
_DEFAULT_MASTER_TYPE="cx32"
_DEFAULT_WORKER_TYPE="cpx51"
_DEFAULT_WORKER_COUNT="3"

: "${LOCATION:=$_DEFAULT_LOCATION}"

_LOCATION="$(prompt_select "Select location" "LOCATION" "$_DEFAULT_LOCATION" $_AVAILABLE_LOCATIONS)"
_ENTRYPOINT="$(prompt_text "Enter network entrypoint" "ENTRYPOINT" "$_DEFAULT_ENTRYPOINT" 1)"

_PFSENSE_HOSTNAME="$(prompt_text "Enter primary pfsense hostname" "PFSENSE_HOSTNAME" "" 1)"
_PFSENSE_SECONDARY="$(prompt_text "Enter secondary pfsense hostname (optional, for HA)" "PFSENSE_SECONDARY" "")"

_MASTER_TYPE="$(prompt_select "Select master node type" "MASTER_TYPE" "$_DEFAULT_MASTER_TYPE" $_AVAILABLE_SERVER_TYPES)"
_WORKER_TYPE="$(prompt_select "Select worker node type" "WORKER_TYPE" "$_DEFAULT_WORKER_TYPE" $_AVAILABLE_SERVER_TYPES)"
_WORKER_COUNT="$(prompt_text "Enter number of worker nodes" "WORKER_COUNT" "$_DEFAULT_WORKER_COUNT" 1)"

_TENANT_TMP_CONFIG_FILE="$(get_tenant_config_file).tmp"
cat <<EOF > "$_TENANT_TMP_CONFIG_FILE"
image: debian-12
location: $_LOCATION
network:
  entrypoint: $_ENTRYPOINT
  lan:
    mtu: 1450
    ipv4:
      subnet: 172.20.0.0/16
    ipv6:
      subnet: fd20::/64
pfsense:
  hostname: $_PFSENSE_HOSTNAME$([ -n "$_PFSENSE_SECONDARY" ] && echo "
  secondary_hostname: $_PFSENSE_SECONDARY")
masters:
  - type: $_MASTER_TYPE
workers:
  - type: $_WORKER_TYPE
    count: $_WORKER_COUNT
EOF
