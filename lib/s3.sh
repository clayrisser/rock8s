#!/bin/sh

set -e

_s3cmd() {
    command -v s3cmd >/dev/null 2>&1 || fail "s3cmd is required for S3 operations (apt install s3cmd / brew install s3cmd)"
    _bucket="$1"
    _region="$2"
    _endpoint="$3"
    _access_key="$4"
    _secret_key="$5"
    shift 5
    _cfg="$(mktemp)"
    trap 'rm -f "$_cfg"' EXIT
    if [ -n "$_endpoint" ]; then
        _host="$(echo "$_endpoint" | sed 's|^https\?://||')"
        _host_bucket="$_host"
    else
        _host="s3.${_region}.amazonaws.com"
        _host_bucket="%(bucket)s.s3.${_region}.amazonaws.com"
    fi
    cat >"$_cfg" <<CFGEOF
[default]
access_key = $_access_key
secret_key = $_secret_key
host_base = $_host
host_bucket = $_host_bucket
CFGEOF
    s3cmd --config="$_cfg" "$@"
    rm -f "$_cfg"
    trap - EXIT
}

s3_put_stdin() {
    _bucket="$1"
    _key="$2"
    _region="$3"
    _endpoint="$4"
    _access_key="$5"
    _secret_key="$6"
    _tmp="$(mktemp)"
    cat >"$_tmp"
    _s3cmd "$_bucket" "$_region" "$_endpoint" "$_access_key" "$_secret_key" \
        put "$_tmp" "s3://${_bucket}/${_key}"
    rm -f "$_tmp"
}

s3_delete_prefix() {
    _bucket="$1"
    _prefix="$2"
    _region="$3"
    _endpoint="$4"
    _access_key="$5"
    _secret_key="$6"
    _s3cmd "$_bucket" "$_region" "$_endpoint" "$_access_key" "$_secret_key" \
        del --recursive --force "s3://${_bucket}/${_prefix}"
}
