#!/bin/sh

set -e

main() {
    _prepare
    _restore_namespace $@
}

_prepare() {
    export NAMESPACE=${_NAMESPACE:-$(kubectl config view --minify --output 'jsonpath={..namespace}')}
    export BACKUP_DIR="$_BACKUP"
    if [ "$BACKUP_DIR" = "" ] || [ ! -d "$BACKUP_DIR" ]; then
        echo "backup directory required" >&2
        exit 1
    fi
}

_restore_namespace() {
    SECRETS="$(kubectl get secrets -n $NAMESPACE 2>/dev/null)"
    DEPLOYMENTS="$(kubectl get deployments -n $NAMESPACE 2>/dev/null)"
    if echo "$SECRETS" | grep -q postgres-postgres-secret; then
        echo "restoring namespace $NAMESPACE"
        sh ./scripts/restore/postgres.sh $@
        echo "restore completed for namespace $NAMESPACE"
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-d) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-l) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        mkdir -p $BACKUP_DIR
        echo "restoring namespace $NAMESPACE"
        sh ./scripts/restore/erpnext.sh $@
        echo "restore completed for namespace $NAMESPACE"
    elif (echo "$SECRETS" | grep -q openldap); then
        mkdir -p $BACKUP_DIR
        echo "restoring namespace $NAMESPACE"
        sh ./scripts/restore/openldap.sh $@
        echo "restore completed for namespace $NAMESPACE"
    else
        echo "no restore scripts for namespace $NAMESPACE" >&2
        exit 1
    fi
}

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            echo "rock8s restore - restore rock8s data"
            echo " "
            echo "rock8s restore [options]"
            echo " "
            echo "options:"
            echo "    -h, --help         show brief help"
            echo "    -n, --namespace    namespace to restore"
            echo "    -b, --backup       backup directory to restore"
            exit 0
        ;;
        -n|--namespace)
            shift
            export _NAMESPACE=$1
            shift
        ;;
        -b|--backup)
            shift
            export _BACKUP=$1
            shift
        ;;
        -*)
            echo "invalid option $1" 1>&2
            exit 1
        ;;
        *)
            break
        ;;
    esac
done

main $@
