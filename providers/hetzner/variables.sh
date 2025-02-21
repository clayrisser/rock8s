#!/bin/sh

set -e

. "$(dirname "$0")/defaults.sh"

for _IMAGE in $AVAILABLE_IMAGES; do
    if [ "$SERVER_IMAGE" = "$_IMAGE" ]; then
        break
    fi
done || {
    echo "invalid server image: $SERVER_IMAGE (available: $AVAILABLE_IMAGES)" >&2
    exit 1
}

for _LOCATION in $AVAILABLE_LOCATIONS; do
    if [ "$LOCATION" = "$_LOCATION" ]; then
        break
    fi
done || {
    echo "invalid location: $LOCATION (available: $AVAILABLE_LOCATIONS)" >&2
    exit 1
}

for _GROUP in $MASTERS; do
    _TYPE="$(echo "$_GROUP" | cut -d: -f1)"
    _COUNT="$(echo "$_GROUP" | cut -d: -f2)"
    _VALID_TYPE=0
    for _SERVER_TYPE in $AVAILABLE_SERVER_TYPES; do
        if [ "$_TYPE" = "$_SERVER_TYPE" ]; then
            _VALID_TYPE=1
            break
        fi
    done
    if [ "$_VALID_TYPE" = "0" ]; then
        echo "invalid server type in master group: $_TYPE (available: $AVAILABLE_SERVER_TYPES)" >&2
        exit 1
    fi
    case "$_COUNT" in
        ''|*[!0-9]*)
            echo "invalid count in master group: $_COUNT (must be a number)" >&2
            exit 1
            ;;
    esac
done

for _GROUP in $WORKERS; do
    _TYPE="$(echo "$_GROUP" | cut -d: -f1)"
    _COUNT="$(echo "$_GROUP" | cut -d: -f2)"
    _VALID_TYPE=0
    for _SERVER_TYPE in $AVAILABLE_SERVER_TYPES; do
        if [ "$_TYPE" = "$_SERVER_TYPE" ]; then
            _VALID_TYPE=1
            break
        fi
    done
    if [ "$_VALID_TYPE" = "0" ]; then
        echo "invalid server type in worker group: $_TYPE (available: $AVAILABLE_SERVER_TYPES)" >&2
        exit 1
    fi
    case "$_COUNT" in
        ''|*[!0-9]*)
            echo "invalid count in worker group: $_COUNT (must be a number)" >&2
            exit 1
            ;;
    esac
done

if [ -z "$HETZNER_TOKEN" ]; then
    echo "missing HETZNER_TOKEN" >&2
    exit 1
fi

export TF_VAR_cluster_name="$CLUSTER_NAME"
export TF_VAR_hetzner_token="$HETZNER_TOKEN"
export TF_VAR_location="$LOCATION"
export TF_VAR_master_groups="$MASTER_GROUPS"
export TF_VAR_network_name="$NETWORK_NAME"
export TF_VAR_server_image="$SERVER_IMAGE"
export TF_VAR_user_data="$USER_DATA"
export TF_VAR_worker_groups="$WORKER_GROUPS"
