#!/bin/sh

DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" | grep release-worker-d | cut -d' ' -f1)
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$DEPLOYMENT_NAME -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')

SITES=$(kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "find ./sites -maxdepth 1 -name assets -prune -o -type d -print | sed 's|^\./sites/\?||g'")

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

for b in $BACKUPS; do
    kubectl cp "$NAMESPACE/$POD_NAME:$b" "$BACKUP_DIR/$(echo $b | grep -oE '[^/]+$')"
    if echo "$b" | grep -q 'private/backups'; then
        kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
            "rm -rf $b"
    fi
done
