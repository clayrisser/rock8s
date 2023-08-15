#!/bin/sh

set -e

DEPLOYMENT_NAME="postgres"
POD_NAME=$(kubectl get pods -l deployment-name=$DEPLOYMENT_NAME -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "no pod found" >&2
    exit 1
fi
if [ -z "$POD_NAME" ]; then
    echo "no pod found for deployment $DEPLOYMENT_NAME" >&2
    exit 1
fi
SECRET_RESOURCE="
$(kubectl get secret postgres-postgres-secret -o json -n "$NAMESPACE")
"

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

kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "PGPASSWORD='$POSTGRES_PASSWORD' pg_dumpall --no-owner --no-acl -p '$POSTGRES_PORT' -U '$POSTGRES_USER'" > "$BACKUP_DIR/dump.sql"
