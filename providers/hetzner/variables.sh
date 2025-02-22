#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/providers/providers.sh"

export TF_VAR_hetzner_token="$(get_config '.providers.hetzner.token // ""' "$HETZNER_TOKEN")"
if [ -z "$TF_VAR_hetzner_token" ]; then
    echo "missing HETZNER_TOKEN" >&2
    exit 1
fi
