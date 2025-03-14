#!/bin/sh

set -e

case "$TF_VAR_purpose" in
    pfsense)
        yaml2json | jq '. + {nodes: .pfsense} | del(.pfsense, .masters, .workers, .provider, .providers, .registries, .addons)'
        ;;
    master)
        yaml2json | jq '. + {nodes: .masters} | del(.pfsense, .masters, .workers, .provider, .providers, .registries, .addons)'
        ;;
    worker)
        yaml2json | jq '. + {nodes: .workers} | del(.pfsense, .masters, .workers, .provider, .providers, .registries, .addons)'
        ;;
    *)
        echo "invalid purpose $TF_VAR_purpose" >&2
        exit 1
        ;;
esac
