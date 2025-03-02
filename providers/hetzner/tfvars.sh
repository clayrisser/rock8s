#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/providers/providers.sh"

_PURPOSE="$1"

if [ -z "$_PURPOSE" ]; then
    echo "purpose is required" >&2
    exit 1
fi

case "$_PURPOSE" in
    pfsense)
        yaml2json | jq '. + {nodes: .pfsense} | del(.pfsense, .masters, .workers, .provider)'
        ;;
    master)
        yaml2json | jq '. + {nodes: .masters} | del(.pfsense, .masters, .workers, .provider)'
        ;;
    worker)
        yaml2json | jq '. + {nodes: .workers} | del(.pfsense, .masters, .workers, .provider)'
        ;;
    *)
        echo "invalid purpose $_PURPOSE" >&2
        exit 1
        ;;
esac
