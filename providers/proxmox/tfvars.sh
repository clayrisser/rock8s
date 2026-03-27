#!/bin/sh

set -e

case "$TF_VAR_purpose" in
master)
    yaml2json | jq '. + {nodes: .masters} | del(.masters, .workers, .provider, .registries, .addons, .image, .location)'
    ;;
worker)
    yaml2json | jq '. + {nodes: .workers} | del(.masters, .workers, .provider, .registries, .addons, .image, .location)'
    ;;
*)
    echo "invalid purpose $TF_VAR_purpose" >&2
    exit 1
    ;;
esac
