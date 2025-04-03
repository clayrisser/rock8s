#!/bin/sh

set -e

wait_for_pod() {
    _NAMESPACE="$1"
    _SELECTOR="$2"
    _CONTAINER="$3"
    _I=0
    while [ $_I -lt $RETRIES ]; do
        _I="$((_I + 1))"
        if [ $_I -gt 1 ]; then
            echo "waiting for pod to be ready $_I/$RETRIES" >&2
            sleep 5
        fi
        _POD_NAME="$(kubectl get pods -l "$_SELECTOR" -n "$_NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
        if [ -n "$_POD_NAME" ]; then
            _CMD="kubectl exec $_POD_NAME -n $_NAMESPACE"
            if [ -n "$_CONTAINER" ]; then
                _CMD="$_CMD -c $_CONTAINER"
            fi
            if $_CMD -- sh -c "echo 'pod is ready'" >/dev/null 2>&1; then
                echo "$_POD_NAME"
                return
            fi
        fi
    done
    return 1
}
