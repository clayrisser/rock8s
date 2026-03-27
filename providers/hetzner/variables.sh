#!/bin/sh

set -e

export TF_VAR_hetzner_token="$(get_config '.providers.hetzner.token // ""' "$HETZNER_TOKEN")"
if [ -z "$TF_VAR_hetzner_token" ]; then
    fail "missing hetzner token (set providers.hetzner.token in config or HETZNER_TOKEN env var)"
fi
