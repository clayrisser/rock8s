#!/bin/sh

set -e

DEPLOYMENT_NAME="postgres"
POD_NAME="$(wait_for_pod "$NAMESPACE" "deployment-name=$DEPLOYMENT_NAME" "database")"
if [ -z "$POD_NAME" ]; then
    fail "no running pod found for deployment $DEPLOYMENT_NAME"
fi
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
backup_create_temp "$POD_NAME" "$NAMESPACE" "database" "$_BACKUP_TMP"
for _DB in $DATABASES; do
    log "backing up postgres database $NAMESPACE/$_DB"
    try "kubectl exec $POD_NAME -n $NAMESPACE -c database -- sh -c \
        \"cd $_BACKUP_TMP && PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h localhost --no-owner --no-acl -p $POSTGRES_PORT -U $POSTGRES_USER $_DB -f $_DB.sql\""
done
backup_compress_temp "$POD_NAME" "$NAMESPACE" "database" "$_BACKUP_TMP" "*.sql"
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"
backup_download_with_progress "$POD_NAME" "$NAMESPACE" "database" "${_BACKUP_TMP}.tar.gz" "./postgres.tar.gz" "$NAMESPACE/postgres"
backup_extract_archive "./postgres.tar.gz" "."
backup_cleanup_temp "$POD_NAME" "$NAMESPACE" "database" "$_BACKUP_TMP"
