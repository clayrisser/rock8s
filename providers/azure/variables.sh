#!/bin/sh

set -e

export TF_VAR_azure_subscription_id="$(get_config '.provider.subscription_id // ""' "$ARM_SUBSCRIPTION_ID")"
if [ -z "$TF_VAR_azure_subscription_id" ]; then
    fail "missing Azure subscription ID (set provider.subscription_id in config or ARM_SUBSCRIPTION_ID env var)"
fi

export TF_VAR_azure_client_id="$(get_config '.provider.client_id // ""' "$ARM_CLIENT_ID")"
if [ -z "$TF_VAR_azure_client_id" ]; then
    fail "missing Azure client ID (set provider.client_id in config or ARM_CLIENT_ID env var)"
fi

export TF_VAR_azure_client_secret="$(get_config '.provider.client_secret // ""' "$ARM_CLIENT_SECRET")"
if [ -z "$TF_VAR_azure_client_secret" ]; then
    fail "missing Azure client secret (set provider.client_secret in config or ARM_CLIENT_SECRET env var)"
fi

export TF_VAR_azure_tenant_id="$(get_config '.provider.tenant_id // ""' "$ARM_TENANT_ID")"
if [ -z "$TF_VAR_azure_tenant_id" ]; then
    fail "missing Azure tenant ID (set provider.tenant_id in config or ARM_TENANT_ID env var)"
fi
