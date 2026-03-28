#!/bin/sh

set -e

get_state_backend() {
    get_config '.state.backend // "local"' "local"
}

generate_backend_config() {
    state_key="$1"
    state_dir="$2"
    backend="$(get_state_backend)"
    case "$backend" in
    local)
        cat <<EOF
terraform {
  backend "local" {
    path = "$state_dir/terraform.tfstate"
  }
}
EOF
        ;;
    s3)
        bucket="$(get_config '.state.bucket // ""')"
        region="$(get_config '.state.region // "us-east-1"')"
        endpoint="$(get_config '.state.endpoint // ""')"
        lock="$(get_config '.state.lock // true')"
        access_key="$(get_config '.state.access_key // ""' "${AWS_ACCESS_KEY_ID:-}")"
        secret_key="$(get_config '.state.secret_key // ""' "${AWS_SECRET_ACCESS_KEY:-}")"
        if [ -z "$bucket" ]; then
            fail "state.bucket required for s3 backend"
        fi
        _creds=""
        if [ -n "$access_key" ] && [ -n "$secret_key" ]; then
            _creds="
    access_key   = \"$access_key\"
    secret_key   = \"$secret_key\""
        fi
        cat <<EOF
terraform {
  backend "s3" {
    bucket       = "$bucket"
    key          = "$state_key"
    region       = "$region"
    use_lockfile = $lock${_creds}$([ -n "$endpoint" ] && printf '\n    endpoint     = "%s"' "$endpoint" || true)
  }
}
EOF
        ;;
    gcs)
        bucket="$(get_config '.state.bucket // ""')"
        if [ -z "$bucket" ]; then
            fail "state.bucket required for gcs backend"
        fi
        cat <<EOF
terraform {
  backend "gcs" {
    bucket = "$bucket"
    prefix = "$state_key"
  }
}
EOF
        ;;
    azblob)
        container="$(get_config '.state.container // ""')"
        account="$(get_config '.state.storage_account // ""')"
        if [ -z "$container" ] || [ -z "$account" ]; then
            fail "state.container and state.storage_account required for azblob backend"
        fi
        cat <<EOF
terraform {
  backend "azurerm" {
    storage_account_name = "$account"
    container_name       = "$container"
    key                  = "$state_key"
  }
}
EOF
        ;;
    *)
        fail "unsupported state backend: $backend"
        ;;
    esac
}

write_backend_config() {
    provider_dir="$1"
    state_key="$2"
    state_dir="$3"
    generate_backend_config "$state_key" "$state_dir" >"$provider_dir/_backend.tf"
}

get_state_key() {
    cluster="$1"
    purpose="$2"
    echo "${cluster}/${purpose}/terraform.tfstate"
}

unset_s3_env() {
    if [ "$(get_state_backend)" = "s3" ]; then
        unset AWS_ACCESS_KEY_ID 2>/dev/null || true
        unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
    fi
}

extract_ssh_private_key() {
    output_file="$1"
    key_file="$2"
    jq -r '.node_ssh_private_key.value // empty' <"$output_file" >"$key_file"
    chmod 600 "$key_file"
}
