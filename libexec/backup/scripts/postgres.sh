#!/bin/sh

set -e

DEPLOYMENT_NAME="postgres"
POD_NAME=$(kubectl get pods -l deployment-name=$DEPLOYMENT_NAME -n "$NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "no running pod found for deployment $DEPLOYMENT_NAME" >&2
    exit 1
fi
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
DATABASES=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "PGPASSWORD='$POSTGRES_PASSWORD' psql -h localhost -p '$POSTGRES_PORT' -U '$POSTGRES_USER' -t -c 'SELECT datname FROM pg_database WHERE datistemplate = false;'")
if [ -z "$DATABASES" ]; then
    exit
fi
_BACKUP_TMP="$(mktemp -d)"
try "kubectl exec '$POD_NAME' -n '$NAMESPACE' --request-timeout=10m -- sh -c 'rm -rf $_BACKUP_TMP >/dev/null 2>&1 || true'"
try "kubectl exec '$POD_NAME' -n '$NAMESPACE' --request-timeout=10m -- sh -c 'mkdir -p $_BACKUP_TMP'"
for _D in $DATABASES; do
    echo "backing up database $_D"
    try "kubectl exec '$POD_NAME' -n '$NAMESPACE' --request-timeout=10m -- sh -c 'cd $_BACKUP_TMP && PGPASSWORD=\"$POSTGRES_PASSWORD\" pg_dump -h localhost --no-owner --no-acl -p \"$POSTGRES_PORT\" -U \"$POSTGRES_USER\" $_D > $_D.sql'"
done
try "kubectl exec '$POD_NAME' -n '$NAMESPACE' --request-timeout=10m -- sh -c 'cd $_BACKUP_TMP && tar czf sql.tar.gz *.sql >/dev/null 2>&1'"
SIZE="$(kubectl exec "$POD_NAME" -n "$NAMESPACE" --request-timeout=10m -- sh -c "cd $_BACKUP_TMP && du -b sql.tar.gz | cut -f1")"
mkdir -p "$BACKUP_DIR"
echo "downloading databases ($SIZE bytes)"
try "kubectl cp '$NAMESPACE/$POD_NAME:$_BACKUP_TMP/sql.tar.gz' '$BACKUP_DIR/sql.tar.gz' >/dev/null 2>&1"
(cd "$BACKUP_DIR" && try "tar xzf sql.tar.gz" && rm sql.tar.gz)
try "kubectl exec '$POD_NAME' -n '$NAMESPACE' --request-timeout=10m -- sh -c 'rm -rf $_BACKUP_TMP'" || true
