#!/bin/sh

set -e

_CONFIG_FILE="$1"
. "$(dirname "$0")/../providers.sh"
. "$(dirname "$0")/defaults.sh"

_validate_ipv4() {
    echo "$1" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' >/dev/null || return 1
    IFS=.
    for _OCTET in $1; do
        [ "$_OCTET" -le 255 ] || return 1
    done
    unset IFS
    return 0
}

_IMAGE="$(prompt_enum "Select server image" "SERVER_IMAGE" "$DEFAULT_IMAGE" $AVAILABLE_IMAGES)"
_LOCATION="$(prompt_enum "Select location" "LOCATION" "$DEFAULT_LOCATION" $AVAILABLE_LOCATIONS)"
_NETWORK="$(prompt_text "Enter network name" "NETWORK_NAME" "$DEFAULT_NETWORK_NAME")"
_PFSENSE_TYPE="$(prompt_enum "Select PFSense node type" "" "$DEFAULT_SERVER_TYPE" $AVAILABLE_SERVER_TYPES)"
_SECONDARY_PFSENSE="$(prompt_boolean "Do you want to add a secondary PFSense node for high availability" "" "0")"
_PFSENSE_COUNT="$([ "$_SECONDARY_PFSENSE" = "1" ] && echo "2" || echo "1")"
_MASTER_TYPE="$(prompt_enum "Select master node type" "" "$DEFAULT_SERVER_TYPE" $AVAILABLE_SERVER_TYPES)"
_USE_IPV4="$(prompt_boolean "Do you want to specify IPv4 addresses for master nodes" "" "0")"
_MASTER_IPV4S=""
if [ "$_USE_IPV4" = "1" ]; then
    _PROMPT="Enter IPv4 address for master node"
    while true; do
        _IPV4="$(prompt_text "$_PROMPT" "" "")"
        if _validate_ipv4 "$_IPV4"; then
            break
        fi
        _PROMPT="Invalid IPv4 address. Enter IPv4 address for master node"
    done
    _MASTER_IPV4S="[\"$_IPV4\"]"
fi
_WORKER_TYPE="$(prompt_enum "Select worker node type" "" "$DEFAULT_SERVER_TYPE" $AVAILABLE_SERVER_TYPES)"
_WORKER_COUNT="$(prompt_text "Enter number of worker nodes" "" "$DEFAULT_WORKER_COUNT")"

cat <<EOF > "$_CONFIG_FILE"
cluster_dir: "$CLUSTER_DIR"
server_image: "$_IMAGE"
location: "$_LOCATION"
network_name: "$_NETWORK"
pfsense:
  - type: $_PFSENSE_TYPE
    count: $_PFSENSE_COUNT
masters:
  - type: $_MASTER_TYPE$([ -n "$_MASTER_IPV4S" ] && echo "
    ipv4s: $_MASTER_IPV4S")
workers:
  - type: $_WORKER_TYPE
    count: $_WORKER_COUNT
EOF
