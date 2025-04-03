#!/bin/sh

set -e

DEPLOYMENT_NAMES=$(kubectl get deployment -n "$NAMESPACE" | grep -E 'release-worker-(d|l|s)' | cut -d' ' -f1)
if [ -z "$DEPLOYMENT_NAMES" ]; then
    fail "no deployment found"
fi
DEPLOYMENT_NAME=""
POD_NAME=""
for _deployment_name in $DEPLOYMENT_NAMES; do
    DEPLOYMENT_NAME="$_deployment_name"
    POD_NAME="$(kubectl get pods -l app.kubernetes.io/instance=$DEPLOYMENT_NAME -n "$NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    if [ "$POD_NAME" != "" ]; then
        break
    fi
done
if [ "$POD_NAME" = "" ]; then
    fail "no running pod found for deployments $DEPLOYMENT_NAMES"
fi
_BACKUP_TMP="/home/frappe/.rock8s_backup"
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"rm -rf $_BACKUP_TMP* || true\""
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"mkdir -p $_BACKUP_TMP\""
SITES="$(kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c "find /home/frappe/frappe-bench/sites -maxdepth 1 -name assets -prune -o -name _backup_tmp -prune -o -type d -print | sed 's|^/home/frappe/frappe-bench/sites/\?||g'" | sed '/^$/d')"
if [ -z "$SITES" ]; then
    fail "no sites found"
fi
for _S in $SITES; do
    log "backing up erpnext site $NAMESPACE/$_S"
    try "kubectl exec -i $POD_NAME -n $NAMESPACE -- sh -c \"cd /home/frappe/frappe-bench && bench --site $_S backup --with-files --backup-path $_BACKUP_TMP\""
done
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"cd $_BACKUP_TMP && tar czf ${_BACKUP_TMP}.tar.gz *\""
SIZE=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -- sh -c "wc -c < ${_BACKUP_TMP}.tar.gz")
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"
try "kubectl cp --retries=$RETRIES $NAMESPACE/$POD_NAME:${_BACKUP_TMP}.tar.gz ./erpnext.tar.gz" >/dev/null 2>&1 &
_START_TIME=$(date +%s)
_LAST_SIZE=0
while [ ! -f ./erpnext.tar.gz ] || [ "$(wc -c < ./erpnext.tar.gz)" -lt "$SIZE" ]; do
    [ -f ./erpnext.tar.gz ] && _CURRENT_SIZE=$(wc -c < ./erpnext.tar.gz) || _CURRENT_SIZE=0
    _ELAPSED=$(($(date +%s) - _START_TIME))
    [ $_ELAPSED -eq 0 ] && _RATE=0 || _RATE=$((_CURRENT_SIZE / _ELAPSED))
    _PERCENT=$((_CURRENT_SIZE * 100 / SIZE))
    show_progress "$NAMESPACE/erpnext" $_CURRENT_SIZE $SIZE $_RATE $_PERCENT
    _LAST_SIZE=$_CURRENT_SIZE
    sleep 1
done
wait
if [ ! -f ./erpnext.tar.gz ] || [ "$(wc -c < ./erpnext.tar.gz)" -ne "$SIZE" ]; then
    rm -f erpnext.tar.gz
    fail "failed to download erpnext backup"
fi
printf "\033[2K\r%s %s %s\n" "$NAMESPACE/erpnext" "████████████████████" "$(format_size $SIZE)" >&2
try "tar xzf erpnext.tar.gz"
rm -f erpnext.tar.gz
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"rm -rf $_BACKUP_TMP*\""
