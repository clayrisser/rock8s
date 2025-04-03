#!/bin/sh

set -e

DEPLOYMENT_NAMES=$(echo $(kubectl get deployment -n "$NAMESPACE" | grep -E 'release-worker-(d|l|s)' | cut -d' ' -f1))
if [ -z "$DEPLOYMENT_NAMES" ]; then
    fail "no deployment found"
fi
DEPLOYMENT_NAME=""
POD_NAME=""
for _D in $DEPLOYMENT_NAMES; do
    DEPLOYMENT_NAME="$_D"
    POD_NAME="$(wait_for_pod "$NAMESPACE" "app.kubernetes.io/instance=$DEPLOYMENT_NAME" "")"
    if [ -n "$POD_NAME" ]; then
        break
    fi
done
if [ -z "$POD_NAME" ]; then
    fail "no running pod found for deployments $DEPLOYMENT_NAMES"
fi
_BACKUP_TMP="/home/frappe/.rock8s_backup"
backup_create_temp "$POD_NAME" "$NAMESPACE" "" "$_BACKUP_TMP"
SITES=$(kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c "find /home/frappe/frappe-bench/sites -maxdepth 1 -name assets -prune -o -name _backup_tmp -prune -o -type d -print|sed 's|^/home/frappe/frappe-bench/sites/\?||g'"|sed '/^$/d')
if [ -z "$SITES" ]; then
    fail "no sites found"
fi
for _S in $SITES; do
    log "backing up erpnext site $NAMESPACE/$_S"
    try "kubectl exec -i $POD_NAME -n $NAMESPACE -- sh -c \"cd /home/frappe/frappe-bench && bench --site $_S backup --with-files --backup-path $_BACKUP_TMP\""
done
backup_compress_temp "$POD_NAME" "$NAMESPACE" "" "$_BACKUP_TMP" "*"
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"
backup_download_with_progress "$POD_NAME" "$NAMESPACE" "" "${_BACKUP_TMP}.tar.gz" "./erpnext.tar.gz" "$NAMESPACE/erpnext"
backup_extract_archive "./erpnext.tar.gz" "."
backup_cleanup_temp "$POD_NAME" "$NAMESPACE" "" "$_BACKUP_TMP"
