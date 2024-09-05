#!/bin/sh

set -e

sh "$PROJECT_ROOT/ceph/scripts/fix-permissions.sh"
MOUNT=$(ls /mnt/pve | grep storagebox || ls /mnt/pve | grep cephfs)
if [ "$MOUNT" != "" ]; then
    BUCKETS_SYNC_DIR="${BUCKETS_SYNC_DIR:-/mnt/pve/$MOUNT/radosgw-buckets}"
fi
if [ "$BUCKETS_SYNC_DIR" = "" ]; then
    echo "BUCKETS_SYNC_DIR is not set" >&2
    exit 1
fi

if ! sudo test -f /root/.s3cfg; then
    sudo cp "$HOME/.s3cfg" /root/.s3cfg
fi
if [ ! -d "$BUCKETS_SYNC_DIR" ]; then
    sudo mkdir -p "$BUCKETS_SYNC_DIR"
fi
for b in $(s3cmd ls | sed 's|^.*\/||g'); do
    if [ ! -d "$BUCKETS_SYNC_DIR/$b" ]; then
        sudo mkdir -p "$BUCKETS_SYNC_DIR/$b"
    fi
    sudo s3cmd sync s3://$b "$BUCKETS_SYNC_DIR/$b"
done
