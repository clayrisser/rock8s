#!/bin/sh

set -e

export TF_VAR_digitalocean_token="$(get_config '.provider.token // ""' "$DIGITALOCEAN_TOKEN")"
if [ -z "$TF_VAR_digitalocean_token" ]; then
    fail "missing DigitalOcean token (set provider.token in config or DIGITALOCEAN_TOKEN env var)"
fi
