#!/bin/sh

set -e

TEMP_POLICY_FILE=$(mktemp)
cleanup() {
    rm -f "$TEMP_POLICY_FILE"
}
trap 'cleanup' EXIT INT TERM HUP QUIT
for b in $(s3cmd ls | sed 's|^.*\/||g'); do
    cat "$PROJECT_ROOT/ceph/policy.json.tmpl" | BUCKET_NAME="$b" sh "$PROJECT_ROOT/scripts/tmpl.sh" > "$TEMP_POLICY_FILE"
    s3cmd setpolicy "$TEMP_POLICY_FILE" s3://$b
done
