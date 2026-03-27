#!/bin/sh

set -e

DEPLOYMENT_NAME="mongodb-rs0"
POD_NAME="$(wait_for_pod "$NAMESPACE" "app.kubernetes.io/instance=$DEPLOYMENT_NAME" "")"
if [ -z "$POD_NAME" ]; then
    fail "no running pod found for deployment $DEPLOYMENT_NAME"
fi
MONGODB_USER="$(kubectl get secret mongodb -n "$NAMESPACE" -o jsonpath='{.data.MONGODB_DATABASE_ADMIN_USER}' | base64 -d)"
MONGODB_PASSWORD="$(kubectl get secret mongodb -n "$NAMESPACE" -o jsonpath='{.data.MONGODB_USER_ADMIN_PASSWORD}' | base64 -d)"
if [ -z "$MONGODB_USER" ] || [ -z "$MONGODB_PASSWORD" ]; then
    fail "failed to get mongodb credentials"
fi
_BACKUP_TMP="/data/.rock8s_backup"
backup_create_temp "$POD_NAME" "$NAMESPACE" "" "$_BACKUP_TMP"
log "backing up mongodb database $NAMESPACE/mongodb"
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"cd $_BACKUP_TMP && mongodump --uri=mongodb://$MONGODB_USER:$MONGODB_PASSWORD@localhost:27017 --gzip --archive=${_BACKUP_TMP}.tar.gz\""
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"
backup_download_with_progress "$POD_NAME" "$NAMESPACE" "" "${_BACKUP_TMP}.tar.gz" "./mongo.tar.gz" "$NAMESPACE/mongodb"
backup_extract_archive "./mongo.tar.gz" "."
backup_cleanup_temp "$POD_NAME" "$NAMESPACE" "" "$_BACKUP_TMP"
