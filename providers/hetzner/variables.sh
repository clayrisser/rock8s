#!/bin/sh

set -e

if [ -z "$HETZNER_TOKEN" ]; then
    echo "missing HETZNER_TOKEN environment variable" >&2
    exit 1
fi

export TF_VAR_hetzner_token="$HETZNER_TOKEN"
