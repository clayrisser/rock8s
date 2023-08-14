#!/bin/sh

set -e

DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" | grep release-worker-d | cut -d' ' -f1)
if [ -z "$DEPLOYMENT_NAME" ]; then
    echo "no deployment found"
    exit 1
fi

POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$DEPLOYMENT_NAME -n "$NAMESPACE" -o json | \
    jq -r '.items[] | select(.status.containerStatuses? and all(.status.containerStatuses[].ready?; . == true)) | .metadata.name' | \
    head -n 1)
if [ -z "$POD_NAME" ]; then
    echo "no pod found for deployment $DEPLOYMENT_NAME"
    exit 1
fi

SITES="$(kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "find ./sites -maxdepth 1 -name assets -prune -o -type d -print | sed 's|^\./sites/\?||g'" | sed '/^$/d')"
if [ -z "$SITES" ]; then
    echo "no sites found"
    exit 1
fi

BACKUPS=""
for s in $SITES; do
    for f in $( (kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
            "echo bench --site $s backup --with-files && bench --site $s backup --with-files") | \
            grep -E '^((Config)|(Database)|(Public)|(Private)) *: \.\/' | sed 's|^\w\+ *: \.||g' | cut -d' ' -f1); do
        if echo "$f" | grep -q 'private/backups'; then
            BACKUPS="$BACKUPS
$(echo /home/frappe/frappe-bench/sites$f)"
        fi
    done
done
if [ -z "$BACKUPS" ]; then
    echo "no backups found"
    exit 1
fi

for b in $BACKUPS; do
    kubectl cp "$NAMESPACE/$POD_NAME:$b" "$BACKUP_DIR/$(echo $b | grep -oE '[^/]+$')"
    if echo "$b" | grep -q 'private/backups'; then
        kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
            "rm -rf $b"
    fi
done
