#!/bin/sh

set -e

_CONFIG_FILE="$1"
. "$(dirname "$0")/../providers.sh"
. "$(dirname "$0")/defaults.sh"

_LOCATION="$(prompt_enum "Select location" "LOCATION" "$DEFAULT_LOCATION" $AVAILABLE_LOCATIONS)"
_NETWORK="$(prompt_text "Enter network" "NETWORK" "$DEFAULT_NETWORK")"
_PFSENSE_TYPE="$(prompt_enum "Select pfsense node type" "" "$DEFAULT_SERVER_TYPE" $AVAILABLE_SERVER_TYPES)"

_PROMPT="Enter primary pfsense hostname"
while true; do
    _PRIMARY_HOSTNAME="$(prompt_text "$_PROMPT" "" "")"
    if [ -n "$_PRIMARY_HOSTNAME" ] && validate_hostname "$_PRIMARY_HOSTNAME"; then
        break
    fi
    _PROMPT="Invalid hostname. Enter primary pfsense hostname"
done

_PROMPT="Enter secondary pfsense hostname (optional)"
while true; do
    _SECONDARY_HOSTNAME="$(prompt_text "$_PROMPT" "" "")"
    if [ -z "$_SECONDARY_HOSTNAME" ] || validate_hostname "$_SECONDARY_HOSTNAME"; then
        break
    fi
    _PROMPT="Invalid hostname. Enter secondary pfsense hostname (optional)"
done

_PFSENSE_HOSTNAMES="[\"$_PRIMARY_HOSTNAME\""
if [ -n "$_SECONDARY_HOSTNAME" ]; then
    _PFSENSE_HOSTNAMES="$_PFSENSE_HOSTNAMES,\"$_SECONDARY_HOSTNAME\""
fi
_PFSENSE_HOSTNAMES="$_PFSENSE_HOSTNAMES]"
_MASTER_TYPE="$(prompt_enum "Select master node type" "" "$DEFAULT_SERVER_TYPE" $AVAILABLE_SERVER_TYPES)"
_USE_IPV4="$(prompt_boolean "Do you want to specify ipv4 addresses for master nodes" "" "0")"
_MASTER_IPV4S=""
if [ "$_USE_IPV4" = "1" ]; then
    _PROMPT="Enter ipv4 address for master node"
    while true; do
        _IPV4="$(prompt_text "$_PROMPT" "" "")"
        if validate_ipv4 "$_IPV4"; then
            break
        fi
        _PROMPT="Invalid ipv4 address. Enter ipv4 address for master node"
    done
    _MASTER_IPV4S="[\"$_IPV4\"]"
fi
_WORKER_TYPE="$(prompt_enum "Select worker node type" "" "$DEFAULT_SERVER_TYPE" $AVAILABLE_SERVER_TYPES)"
_WORKER_COUNT="$(prompt_text "Enter number of worker nodes" "" "$DEFAULT_WORKER_COUNT")"

cat <<EOF > "$_CONFIG_FILE"
image: debian-12
location: $_LOCATION
network:
  lan:
    subnet: 172.20.0.0/16
pfsense:
  - type: $_PFSENSE_TYPE
    hostnames:
      - $_PRIMARY_HOSTNAME$([ -n "$_SECONDARY_HOSTNAME" ] && echo "
      - $_SECONDARY_HOSTNAME")
masters:
  - type: $_MASTER_TYPE$([ -n "$_MASTER_IPV4S" ] && echo "
    ipv4s: $_MASTER_IPV4S")
workers:
  - type: $_WORKER_TYPE
    count: $_WORKER_COUNT
EOF
