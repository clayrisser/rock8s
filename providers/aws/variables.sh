#!/bin/sh

set -e

export TF_VAR_aws_access_key="$(get_config '.provider.access_key // ""' "$AWS_ACCESS_KEY_ID")"
if [ -z "$TF_VAR_aws_access_key" ]; then
    fail "missing AWS access key (set provider.access_key in config or AWS_ACCESS_KEY_ID env var)"
fi

export TF_VAR_aws_secret_key="$(get_config '.provider.secret_key // ""' "$AWS_SECRET_ACCESS_KEY")"
if [ -z "$TF_VAR_aws_secret_key" ]; then
    fail "missing AWS secret key (set provider.secret_key in config or AWS_SECRET_ACCESS_KEY env var)"
fi
