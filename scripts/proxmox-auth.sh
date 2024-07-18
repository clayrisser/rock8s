#!/bin/sh

set -- $(sudo pveum user token add root@pam "$(tr -dc 'a-z' < /dev/urandom | head -c 8)" --privsep 0 -o json | \
    jq -r '([.["full-tokenid"],.value]) | @tsv')
export PROXMOX_TOKEN_ID="$1"
export PROXMOX_TOKEN_SECRET="$2"
export STORAGE_POOL="$( (sudo pvesm status | grep -q rbd) && echo rbd || ( (sudo pvesm status | grep -q local-zfs) && echo local-zfs || ( (sudo pvesm status | grep -q local-lvm) && echo local-lvm || echo local)))"
export PROXMOX_NODE="$(hostname)"
export PROXMOX_HOST="localhost:8006"
