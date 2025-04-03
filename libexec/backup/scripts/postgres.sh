#!/bin/sh

set -e

DEPLOYMENT_NAME="postgres"
POD_NAME=$(wait_for_pod "$NAMESPACE" "deployment-name=$DEPLOYMENT_NAME" "database")
SECRET_RESOURCE="$(kubectl get secret postgres-postgres-secret -o json -n "$NAMESPACE")"
POSTGRES_PASSWORD="$(echo "$SECRET_RESOURCE" | jq -r '.data.password' | openssl base64 -d)"
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "no postgres password found" >&2
    exit 1
fi
POSTGRES_USER="$(echo "$SECRET_RESOURCE" | jq -r '.data.username' | openssl base64 -d)"
if [ -z "$POSTGRES_USER" ]; then
    echo "no postgres user found" >&2
    exit 1
fi
POSTGRES_PORT="5432"
DATABASES=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -c database -- sh -c \
    "PGPASSWORD='$POSTGRES_PASSWORD' psql -h localhost -p '$POSTGRES_PORT' -U '$POSTGRES_USER' -t -c 'SELECT datname FROM pg_database WHERE datistemplate = false;'" | tr -d ' ' | grep -v '^$')
if [ -z "$DATABASES" ]; then
    exit
fi
_BACKUP_TMP="/pgdata/_backup_tmp"
try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \"rm -rf $_BACKUP_TMP || true\""
try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \"mkdir -p $_BACKUP_TMP\""
echo "$DATABASES" | while IFS= read -r _D; do
    wait_for_pod "$NAMESPACE" "deployment-name=$DEPLOYMENT_NAME" "database" >/dev/null
    echo "backing up database $_D" >&2
    try "kubectl exec $POD_NAME -n $NAMESPACE -c database --request-timeout=30m -- sh -c \"cd $_BACKUP_TMP && PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h localhost --no-owner --no-acl --jobs=1 -p $POSTGRES_PORT -U $POSTGRES_USER $_D > $_D.sql\""
done
try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \"cd $_BACKUP_TMP && tar cf - *.sql | gzip -1 > sql.tar.gz\""
SIZE="$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -c database -- sh -c "cd $_BACKUP_TMP && du -b sql.tar.gz | cut -f1")"
mkdir -p "$BACKUP_DIR"
rm -f "$BACKUP_DIR/sql.tar.gz"
cd "$BACKUP_DIR"
kubectl cp --retries=$RETRIES $NAMESPACE/$POD_NAME:$_BACKUP_TMP/sql.tar.gz ./sql.tar.gz >/dev/null 2>&1 &
while [ ! -f ./sql.tar.gz ] || [ "$(wc -c < ./sql.tar.gz)" -lt "$SIZE" ]; do
    [ -f ./sql.tar.gz ] && CURRENT_SIZE=$(wc -c < ./sql.tar.gz) || CURRENT_SIZE=0
    PERCENT=$((CURRENT_SIZE * 100 / SIZE))
    printf "\033[2K\rdownloading databases: %d%% (%d/%d bytes)" $PERCENT $CURRENT_SIZE $SIZE >&2
    sleep 1
done
printf "\033[2K\rdownloading databases: 100%% (%d/%d bytes)\n" $SIZE $SIZE >&2
wait
if [ ! -f ./sql.tar.gz ] || [ "$(wc -c < ./sql.tar.gz)" -ne "$SIZE" ]; then
    echo "failed to download databases" >&2
    exit 1
fi
tar xzf sql.tar.gz && rm -f sql.tar.gz
try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \"rm -rf $_BACKUP_TMP\""
