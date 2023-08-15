#!/bin/sh

set -e

SECRET_RESOURCE="
$(kubectl get secret postgres-postgres-secret -o json -n "$NAMESPACE")
"
DEPLOYMENT_NAME="postgres"
POD_NAME=$(kubectl get pods -l deployment-name=$DEPLOYMENT_NAME -n "$NAMESPACE" -o json | \
    jq -r '.items[] | select(.status.containerStatuses? and all(.status.containerStatuses[].ready?; . == true)) | .metadata.name' | \
    head -n 1)
if [ -z "$POD_NAME" ]; then
    echo "no pod found" >&2
    exit 1
fi

export POSTGRES_PASSWORD="$(echo "$SECRET_RESOURCE" | jq -r '.data.password' | openssl base64 -d)"
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "no postgres password found" >&2
    exit 1
fi
export POSTGRES_USER="$(echo "$SECRET_RESOURCE" | jq -r '.data.username' | openssl base64 -d)"
if [ -z "$POSTGRES_USER" ]; then
    echo "no postgres username found" >&2
    exit 1
fi
export POSTGRES_PORT="5432"

REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -o json -n "$NAMESPACE" | jq '.spec.replicas')
if [ -z "$REPLICAS" ]; then
    echo "no replicas found" >&2
    exit 1
fi
if [ "$REPLICAS" -gt 1 ]; then
    kubectl scale --replicas=1 deployment/$DEPLOYMENT_NAME -n "$NAMESPACE"
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n "$NAMESPACE"
    POD_NAME=$(kubectl get pods -l deployment-name=$DEPLOYMENT_NAME -n "$NAMESPACE" -o json | \
        jq -r '.items[] | select(.status.containerStatuses? and all(.status.containerStatuses[].ready?; . == true)) | .metadata.name' | \
        head -n 1)
fi
if [ -z "$POD_NAME" ]; then
    echo "no pod found" >&2
    exit 1
fi

DATABASES="$(ls "$BACKUP_DIR" | grep -E '\.sql$' | sed 's|\.sql$||g')"
for d in $DATABASES; do
    POSTGRES_DATABASE="$d"
    cat "$BACKUP_DIR/$d.sql" | kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
        "PGPASSWORD='$POSTGRES_PASSWORD' psql -p '$POSTGRES_PORT' -U '$POSTGRES_USER' -d '$POSTGRES_DATABASE'"
done

if [ "$REPLICAS" -gt 1 ]; then
    kubectl scale --replicas=$REPLICAS deployment/$DEPLOYMENT_NAME -n "$NAMESPACE"
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n "$NAMESPACE"
fi
