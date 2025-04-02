#!/bin/sh
set -e
. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF
NAME
       rock8s restore

SYNOPSIS
       rock8s restore [-h] [-n <namespace>] [-b <backup>]

DESCRIPTION
       restore cluster data and configurations

OPTIONS
       -h, --help
              show this help message
       -n, --namespace <namespace>
              namespace to restore
       -b, --backup <backup>
              backup to restore from (timestamp format)
EOF
}

_restore_namespace() {
    if [ -z "$_BACKUP" ]; then
        _BACKUP=$(ls -t "$ROCK8S_STATE_HOME/backups/$NAMESPACE" | head -n1)
    fi
    export BACKUP_DIR="$ROCK8S_STATE_HOME/backups/$NAMESPACE/$_BACKUP"
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "backup not found: $BACKUP_DIR" >&2
        exit 1
    fi
    SECRETS="$(kubectl get secrets -n $NAMESPACE 2>/dev/null)"
    DEPLOYMENTS="$(kubectl get deployments -n $NAMESPACE 2>/dev/null)"
    _restore_releases
    _restore_configmaps
    _restore_secrets
    if echo "$SECRETS" | grep -q postgres-postgres-secret; then
        echo "restoring namespace $NAMESPACE"
        sh "$ROCK8S_LIB_PATH/libexec/backup/scripts/postgres.sh"
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-d) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-l) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        echo "restoring namespace $NAMESPACE"
        sh "$ROCK8S_LIB_PATH/libexec/backup/scripts/erpnext.sh"
    elif (echo "$SECRETS" | grep -q openldap); then
        echo "restoring namespace $NAMESPACE"
        sh "$ROCK8S_LIB_PATH/libexec/backup/scripts/openldap.sh"
    else
        echo "no restore scripts for namespace $NAMESPACE" >&2
    fi
    echo "restore completed for namespace $NAMESPACE"
}

_restore_secrets() {
    if [ -d "$BACKUP_DIR/secrets" ]; then
        for f in $BACKUP_DIR/secrets/*.yaml; do
            [ -f "$f" ] || continue
            n=$(basename "$f" | sed 's/\.yaml$//')
            echo "restoring secret $NAMESPACE/$n"
            kubectl apply -f "$f"
        done
    fi
}

_restore_configmaps() {
    if [ -d "$BACKUP_DIR/configmaps" ]; then
        for f in $BACKUP_DIR/configmaps/*.yaml; do
            [ -f "$f" ] || continue
            n=$(basename "$f" | sed 's/\.yaml$//')
            echo "restoring configmap $NAMESPACE/$n"
            kubectl apply -f "$f"
        done
    fi
}

_restore_releases() {
    if [ -d "$BACKUP_DIR/releases" ]; then
        for f in $BACKUP_DIR/releases/*.yaml; do
            [ -f "$f" ] || continue
            n=$(basename "$f" | sed 's/\.yaml$//')
            echo "restoring helm release $NAMESPACE/$n"
            kubectl apply -f "$f"
        done
    fi
}

_main() {
    if [ -z "$NAMESPACE" ]; then
        echo "namespace is required" >&2
        exit 1
    fi
    _restore_namespace
}

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            _help
            exit 0
            ;;
        -n|--namespace)
            shift
            export NAMESPACE=$1
            shift
            ;;
        -b|--backup)
            shift
            export _BACKUP=$1
            shift
            ;;
        -*)
            echo "invalid option $1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

_main
