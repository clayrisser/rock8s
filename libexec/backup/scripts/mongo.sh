#!/bin/sh

set -e

DEPLOYMENT_NAME="mongodb-rs0"
POD_NAME="$(kubectl get pods -l app.kubernetes.io/instance=$DEPLOYMENT_NAME -n "$NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
if [ "$POD_NAME" = "" ]; then
    fail "no running pod found for deployment $DEPLOYMENT_NAME"
fi

MONGODB_USER="$(kubectl get secret mongodb -n "$NAMESPACE" -o jsonpath='{.data.MONGODB_DATABASE_ADMIN_USER}' | base64 -d)"
MONGODB_PASSWORD="$(kubectl get secret mongodb -n "$NAMESPACE" -o jsonpath='{.data.MONGODB_USER_ADMIN_PASSWORD}' | base64 -d)"
if [ -z "$MONGODB_USER" ] || [ -z "$MONGODB_PASSWORD" ]; then
    fail "failed to get mongodb credentials"
fi

_BACKUP_TMP="/data/.rock8s_backup"
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"rm -rf $_BACKUP_TMP* || true\""
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"mkdir -p $_BACKUP_TMP\""
log "backing up mongodb database $NAMESPACE/mongodb"
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"cd $_BACKUP_TMP && mongodump --uri=mongodb://$MONGODB_USER:$MONGODB_PASSWORD@localhost:27017 --gzip --archive=${_BACKUP_TMP}.tar.gz\""
SIZE=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -- sh -c "wc -c < ${_BACKUP_TMP}.tar.gz")
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"
rm -f mongo.tar.gz
try "kubectl cp --retries=$RETRIES $NAMESPACE/$POD_NAME:${_BACKUP_TMP}.tar.gz ./mongo.tar.gz" >/dev/null 2>&1 &
_START_TIME=$(date +%s)
_LAST_SIZE=0
while [ ! -f ./mongo.tar.gz ] || [ "$(wc -c < ./mongo.tar.gz)" -lt "$SIZE" ]; do
    [ -f ./mongo.tar.gz ] && _CURRENT_SIZE=$(wc -c < ./mongo.tar.gz) || _CURRENT_SIZE=0
    _ELAPSED=$(($(date +%s) - _START_TIME))
    [ $_ELAPSED -eq 0 ] && _RATE=0 || _RATE=$((_CURRENT_SIZE / _ELAPSED))
    _PERCENT=$((_CURRENT_SIZE * 100 / SIZE))
    show_progress "$NAMESPACE/mongodb" $_CURRENT_SIZE $SIZE $_RATE $_PERCENT
    _LAST_SIZE=$_CURRENT_SIZE
    sleep 1
done
wait
if [ ! -f ./mongo.tar.gz ] || [ "$(wc -c < ./mongo.tar.gz)" -ne "$SIZE" ]; then
    rm -f mongo.tar.gz
    fail "failed to download mongodb backup"
fi
printf "\033[2K\r%s %s %s\n" "$NAMESPACE/mongodb" "████████████████████" "$(format_size $SIZE)" >&2
try "tar xzf mongo.tar.gz"
rm -f mongo.tar.gz
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"rm -rf $_BACKUP_TMP*\""
