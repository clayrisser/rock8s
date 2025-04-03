#!/bin/sh

set -e

DEPLOYMENT_NAME="postgres"
POD_NAME=$(wait_for_pod "$NAMESPACE" "deployment-name=$DEPLOYMENT_NAME" "database")
SECRET_RESOURCE="$(kubectl get secret postgres-postgres-secret -o json -n "$NAMESPACE")"
POSTGRES_PASSWORD="$(echo "$SECRET_RESOURCE" | jq -r '.data.password' | openssl base64 -d)"
if [ -z "$POSTGRES_PASSWORD" ]; then
    fail "no postgres password found"
fi
POSTGRES_USER="$(echo "$SECRET_RESOURCE" | jq -r '.data.username' | openssl base64 -d)"
if [ -z "$POSTGRES_USER" ]; then
    fail "no postgres user found"
fi
POSTGRES_PORT="5432"
DATABASES=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -c database -- sh -c \
    "PGPASSWORD='$POSTGRES_PASSWORD' psql -h localhost -p '$POSTGRES_PORT' -U '$POSTGRES_USER' -t -c 'SELECT datname FROM pg_database WHERE datistemplate = false;'" | tr -d ' ' | grep -v '^$')
if [ -z "$DATABASES" ]; then
    exit
fi
_BACKUP_TMP="/pgdata/.rock8s_backup"
try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \"rm -rf $_BACKUP_TMP* || true\""
try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \"mkdir -p $_BACKUP_TMP\""
for _DB in $DATABASES; do
    log "backing up postgres database $NAMESPACE/$_DB"
    try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \
        \"cd $_BACKUP_TMP && PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h localhost --no-owner --no-acl -p $POSTGRES_PORT -U $POSTGRES_USER $_DB -f $_DB.sql\""
done
try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \"cd $_BACKUP_TMP && tar czf ${_BACKUP_TMP}.tar.gz *.sql\""
SIZE=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -c database -- sh -c "wc -c < ${_BACKUP_TMP}.tar.gz")
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"
rm -f postgres.tar.gz
try "kubectl cp --retries=$RETRIES $NAMESPACE/$POD_NAME:${_BACKUP_TMP}.tar.gz ./postgres.tar.gz" >/dev/null 2>&1 &
_START_TIME=$(date +%s)
_LAST_SIZE=0
while [ ! -f ./postgres.tar.gz ] || [ "$(wc -c < ./postgres.tar.gz)" -lt "$SIZE" ]; do
    [ -f ./postgres.tar.gz ] && _CURRENT_SIZE=$(wc -c < ./postgres.tar.gz) || _CURRENT_SIZE=0
    _ELAPSED=$(($(date +%s) - _START_TIME))
    [ $_ELAPSED -eq 0 ] && _RATE=0 || _RATE=$((_CURRENT_SIZE / _ELAPSED))
    _PERCENT=$((_CURRENT_SIZE * 100 / SIZE))
    show_progress "$NAMESPACE/postgres" $_CURRENT_SIZE $SIZE $_RATE $_PERCENT
    _LAST_SIZE=$_CURRENT_SIZE
    sleep 1
done
wait
if [ ! -f ./postgres.tar.gz ] || [ "$(wc -c < ./postgres.tar.gz)" -ne "$SIZE" ]; then
    rm -f postgres.tar.gz
    fail "failed to download postgres backup"
fi
printf "\033[2K\r%s %s %s\n" "$NAMESPACE/postgres" "████████████████████" "$(format_size $SIZE)" >&2
try "tar xzf postgres.tar.gz"
rm -f postgres.tar.gz
try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \"rm -rf $_BACKUP_TMP*\""
