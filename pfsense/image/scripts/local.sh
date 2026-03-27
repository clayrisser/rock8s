#!/bin/sh

export PFSENSE_HOSTNAME="${PFSENSE_HOSTNAME:-127.0.0.1}"
export PFSENSE_PASSWORD="${PFSENSE_PASSWORD:-pfsense}"
export PFSENSE_PORT="${PFSENSE_PORT:-10443}"
export PFSENSE_USERNAME="${PFSENSE_USERNAME:-admin}"
export PFSENSE_URL="https://${PFSENSE_HOSTNAME}:${PFSENSE_PORT}"

start_time="$(date +%s)"
while true; do
    current_time="$(date +%s)"
    elapsed="$((current_time - start_time))"
    if [ $elapsed -ge 300 ]; then
        echo "healthcheck timeout after 300 seconds" >&2
        exit 1
    fi
    if curl -k -s --connect-timeout 5 "$PFSENSE_URL/" > /dev/null 2>&1; then
        break
    fi
    sleep 5
done
node "$(dirname "$0")"/provision.mjs
