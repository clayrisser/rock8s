#!/bin/sh

DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" | grep release-worker-d | cut -d' ' -f1)
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$DEPLOYMENT_NAME -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')

SITES=$(kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "find ./sites -maxdepth 1 -name assets -prune -o -type d -print | sed 's|^\./sites/\?||g'")

BACKUPS=""
for s in $SITES; do
    echo restore not implemented for site $s
done
