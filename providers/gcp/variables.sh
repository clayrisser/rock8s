#!/bin/sh

set -e

_GCP_PROJECT="$(get_config '.provider.project // ""' "$GOOGLE_PROJECT")"
if [ -z "$_GCP_PROJECT" ]; then
    fail "missing GCP project (set provider.project in config or GOOGLE_PROJECT env var)"
fi
export TF_VAR_gcp_project="$_GCP_PROJECT"

_GCP_CREDS="$(get_config '.provider.credentials_file // ""' "$GOOGLE_APPLICATION_CREDENTIALS")"
if [ -n "$_GCP_CREDS" ]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$_GCP_CREDS"
fi
