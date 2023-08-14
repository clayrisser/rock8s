#!/bin/sh

set -e

DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" | grep release-worker-d | cut -d' ' -f1)
if [ -z "$DEPLOYMENT_NAME" ]; then
    echo "no deployment found" >&2
    exit 1
fi

POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$DEPLOYMENT_NAME -n "$NAMESPACE" -o json | \
    jq -r '.items[] | select(.status.containerStatuses? and all(.status.containerStatuses[].ready?; . == true)) | .metadata.name' | \
    head -n 1)
if [ -z "$POD_NAME" ]; then
    echo "no pod found for deployment $DEPLOYMENT_NAME" >&2
    exit 1
fi

SITES="$(kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "find ./sites -maxdepth 1 -name assets -prune -o -type d -print | sed 's|^\./sites/\?||g'" | sed '/^$/d')"
if [ -z "$SITES" ]; then
    echo "no sites found" >&2
    exit 1
fi

BACKUPS=""
for s in $SITES; do
    _BACKUP_NAME=
    _SITE_PATH="/home/frappe/frappe-bench/sites/$s"
    kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
        "rm -rf \"$_SITE_PATH/private/backups\""
    _STDOUT="$(kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c "bench --site $s backup --with-files" 2>&1 || true)"
    echo "$_STDOUT"
    for f in $(echo "$_STDOUT" | grep -E '^((Config)|(Database)|(Public)|(Private)) *: \.\/' | sed 's|^\w\+ *: \.||g' | cut -d' ' -f1); do
        if echo "$f" | grep -qE '\-site_config_backup\.json$'; then
            _BACKUP_NAME="$(echo "$f" | sed 's|.*\/\([0-9]\+_[0-9]\+-.*\)-site_config_backup\.json$|\1|g')"
        fi
        if echo "$f" | grep -q 'private/backups'; then
            BACKUPS="$BACKUPS
$(echo /home/frappe/frappe-bench/sites$f)"
        fi
    done
    if [ -z "$_BACKUP_NAME" ]; then
        echo "failed to detect backup name for site $s" >&2
        exit 1
    fi
done
if [ -z "$BACKUPS" ]; then
    echo "no backups found" >&2
    exit 1
fi

for b in $BACKUPS; do
    kubectl cp --retries="$RETRIES" "$NAMESPACE/$POD_NAME:$b" "$BACKUP_DIR/$(echo $b | grep -oE '[^/]+$')"
    if echo "$b" | grep -q 'private/backups'; then
        kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
            "rm -rf $b"
    fi
done
