#!/bin/sh

set -e

export TF_VAR_vultr_api_key="$(get_config '.provider.api_key // ""' "$VULTR_API_KEY")"
if [ -z "$TF_VAR_vultr_api_key" ]; then
    fail "missing Vultr API key (set provider.api_key in config or VULTR_API_KEY env var)"
fi
