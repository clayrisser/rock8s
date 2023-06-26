#!/bin/sh

DEPLOYMENT_NAME="postgres"
POD_NAME=$(kubectl get pods -l deployment-name=$DEPLOYMENT_NAME -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
SECRET_RESOURCE="
$(kubectl get secret postgres-postgres-secret -o json -n "$NAMESPACE")
"

POSTGRES_PASSWORD="$(echo "$SECRET_RESOURCE" | jq -r '.data.password' | openssl base64 -d)"
POSTGRES_USER="$(echo "$SECRET_RESOURCE" | jq -r '.data.username' | openssl base64 -d)"
POSTGRES_PORT="5432"

kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "PGPASSWORD='$POSTGRES_PASSWORD' pg_dumpall --no-owner --no-acl -p '$POSTGRES_PORT' -U '$POSTGRES_USER'" > "$BACKUP_DIR/dump.sql"
