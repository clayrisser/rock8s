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
_DEFAULT_PFSENSE_TYPE="cx22"

: "${LOCATION:=$_DEFAULT_LOCATION}"

_LOCATION="$(prompt_select "Select location" "LOCATION" "$_DEFAULT_LOCATION" $_AVAILABLE_LOCATIONS)"
_ENTRYPOINT="$(prompt_text "Enter network entrypoint (primary pfSense hostname)" "ENTRYPOINT" "" 1)"

_PFSENSE_TYPE="$(prompt_select "Select pfsense node type" "PFSENSE_TYPE" "$_DEFAULT_PFSENSE_TYPE" $_AVAILABLE_SERVER_TYPES)"

_PRIMARY_HOSTNAME="$_ENTRYPOINT"
_SECONDARY_HOSTNAME="$(prompt_text "Enter secondary pfsense hostname (optional, for HA)" "SECONDARY_HOSTNAME" "")"

_PFSENSE_HOSTNAMES="
      - $_PRIMARY_HOSTNAME"
if [ -n "$_SECONDARY_HOSTNAME" ]; then
    _PFSENSE_HOSTNAMES="$_PFSENSE_HOSTNAMES
      - $_SECONDARY_HOSTNAME"
fi

_TENANT_TMP_CONFIG_FILE="$(get_tenant_config_file).tmp"
cat <<EOF > "$_TENANT_TMP_CONFIG_FILE"
location: $_LOCATION
network:
  entrypoint: $_PRIMARY_HOSTNAME
  lan:
    mtu: 1450
    ipv4:
      subnet: 172.20.0.0/16
    ipv6:
      subnet: fd20::/64$([ -n "$_SECONDARY_HOSTNAME" ] && echo "
  sync:
    ipv4:
      subnet: 172.21.0.0/16")
pfsense:
  - type: $_PFSENSE_TYPE
    hostnames:$_PFSENSE_HOSTNAMES
EOF
