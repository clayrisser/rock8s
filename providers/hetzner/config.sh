#!/bin/sh

set -e

AVAILABLE_LOCATIONS="
nbg1
fsn1
hel1
sin
hil
ash"

AVAILABLE_SERVER_TYPES="
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

AVAILABLE_REGISTRIES="
docker.io
ghcr.io
registry.gitlab.com
public.ecr.aws
quay.io"

DEFAULT_LOCATION="nbg1"
DEFAULT_MASTER_COUNT="1"
DEFAULT_WORKER_TYPE="cx22"
DEFAULT_PFSENSE_TYPE="cx22"
DEFAULT_MASTER_TYPE="cx32"
DEFAULT_WORKER_COUNT="2"

: "${LOCATION:=$DEFAULT_LOCATION}"
: "${NETWORK:=$DEFAULT_NETWORK}"

_CONFIG_FILE="$1"
. "$(dirname "$0")/../providers.sh"

_LOCATION="$(prompt_enum "Select location" "LOCATION" "$DEFAULT_LOCATION" $AVAILABLE_LOCATIONS)"
_ENTRYPOINT="$(prompt_text "Enter network entrypoint" "ENTRYPOINT" "" 1)"
_PFSENSE_TYPE="$(prompt_enum "Select pfsense node type" "" "$DEFAULT_PFSENSE_TYPE" $AVAILABLE_SERVER_TYPES)"

_PRIMARY_HOSTNAME="$(prompt_text "Enter primary pfsense hostname" "" "" 1)"
_SECONDARY_HOSTNAME="$(prompt_text "Enter secondary pfsense hostname" "" "")"

_PFSENSE_HOSTNAMES="[\"$_PRIMARY_HOSTNAME\""
if [ -n "$_SECONDARY_HOSTNAME" ]; then
    _PFSENSE_HOSTNAMES="$_PFSENSE_HOSTNAMES,\"$_SECONDARY_HOSTNAME\""
fi
_PFSENSE_HOSTNAMES="$_PFSENSE_HOSTNAMES]"
_MASTER_TYPE="$(prompt_enum "Select master node type" "" "$DEFAULT_MASTER_TYPE" $AVAILABLE_SERVER_TYPES)"
_WORKER_TYPE="$(prompt_enum "Select worker node type" "" "$DEFAULT_WORKER_TYPE" $AVAILABLE_SERVER_TYPES)"
_WORKER_COUNT="$(prompt_text "Enter number of worker nodes" "" "$DEFAULT_WORKER_COUNT" 1)"

_SELECTED_REGISTRIES="$(prompt_multiselect "Select registries to configure" "" $AVAILABLE_REGISTRIES)"
_REGISTRIES=""
for _REGISTRY in $_SELECTED_REGISTRIES; do
    _REGISTRY_USERNAME="$(prompt_text "Enter username for $_REGISTRY" "" "")"
    _REGISTRY_PASSWORD="$(prompt_password "Enter password for $_REGISTRY" "")"
    if [ -n "$_REGISTRIES" ]; then
        _REGISTRIES="$_REGISTRIES
  $_REGISTRY:
    username: \"$_REGISTRY_USERNAME\"
    password: \"$_REGISTRY_PASSWORD\""
    else
        _REGISTRIES="  $_REGISTRY:
    username: \"$_REGISTRY_USERNAME\"
    password: \"$_REGISTRY_PASSWORD\""
    fi
done

cat <<EOF > "$_CONFIG_FILE"
image: debian-12
location: $_LOCATION
network:
  entrypoint: $_ENTRYPOINT
  lan:
    subnet: 172.20.0.0/16
pfsense:
  - type: $_PFSENSE_TYPE
    hostnames:
      - $_PRIMARY_HOSTNAME$([ -n "$_SECONDARY_HOSTNAME" ] && echo "
      - $_SECONDARY_HOSTNAME")
masters:
  - type: $_MASTER_TYPE
workers:
  - type: $_WORKER_TYPE
    count: $_WORKER_COUNT
EOF

if [ -n "$_REGISTRIES" ]; then
    cat <<EOF >> "$_CONFIG_FILE"
registries:
$_REGISTRIES
EOF
else
    cat <<EOF >> "$_CONFIG_FILE"
registries:
EOF
fi
