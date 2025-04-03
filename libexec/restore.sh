#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s restore

SYNOPSIS
       rock8s restore [-h] [-n <namespace>] [-b <backup>] [--retries <n>]

DESCRIPTION
       restore cluster data and configurations from backup

OPTIONS
       -h, --help
              show this help message

       -n, --namespace <namespace>
              namespace to restore (required)

       -b, --backup <backup>
              backup to restore from (timestamp format, default: latest backup)

       --retries <n>
              number of retries for kubectl operations (default: 3)

EXAMPLE
       # restore latest backup for a namespace
       rock8s restore -n mynamespace

       # restore specific backup
       rock8s restore -n mynamespace -b 1234567890_2024-03-21_12-34-56

       # specify number of retries
       rock8s restore -n mynamespace --retries 5

SEE ALSO
       rock8s backup
              backup cluster data and configurations
EOF
}

_restore_namespace() {
    if [ -z "$_BACKUP" ]; then
        _BACKUP=$(ls -t "$ROCK8S_STATE_HOME/backups/$NAMESPACE" | head -n1)
    fi
    export BACKUP_DIR="$ROCK8S_STATE_HOME/backups/$NAMESPACE/$_BACKUP"
    if [ ! -d "$BACKUP_DIR" ]; then
        fail "backup not found: $BACKUP_DIR"
    fi
    SECRETS="$(kubectl get secrets -n "$NAMESPACE" 2>/dev/null || true)"
    DEPLOYMENTS="$(kubectl get deployments -n "$NAMESPACE" 2>/dev/null || true)"
    if echo "$SECRETS" | grep -q postgres-postgres-secret; then
        . "$ROCK8S_LIB_PATH/libexec/backup/scripts/postgres.sh"
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-d) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-l) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        . "$ROCK8S_LIB_PATH/libexec/backup/scripts/erpnext.sh"
    elif (echo "$SECRETS" | grep -q openldap); then
        . "$ROCK8S_LIB_PATH/libexec/backup/scripts/openldap.sh"
    else
        warn "no restore scripts for namespace $NAMESPACE"
    fi
    echo "restore completed for namespace $NAMESPACE"
}

_main() {
    : "${RETRIES:=3}"
    command -v helm >/dev/null 2>&1 || {
        fail "helm is not installed"
    }
    _NAMESPACE=""
    _BACKUP=""
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
                ;;
            -n|--namespace|-n=*|--namespace=*)
                case "$1" in
                    *=*)
                        _NAMESPACE="${1#*=}"
                        shift
                        ;;
                    *)
                        _NAMESPACE="$2"
                        shift 2
                        ;;
                esac
                ;;
            -b|--backup|-b=*|--backup=*)
                case "$1" in
                    *=*)
                        _BACKUP="${1#*=}"
                        shift
                        ;;
                    *)
                        _BACKUP="$2"
                        shift 2
                        ;;
                esac
                ;;
            --retries|--retries=*)
                case "$1" in
                    *=*)
                        RETRIES="${1#*=}"
                        shift
                        ;;
                    *)
                        RETRIES="$2"
                        shift 2
                        ;;
                esac
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
    if [ -z "$_NAMESPACE" ]; then
        fail "namespace is required"
    fi
    export RETRIES
    export NAMESPACE="$_NAMESPACE"
    _restore_namespace
}

_main "$@"
