#!/bin/sh

main() {
    _prepare
    if [ "$_ALL" = "1" ]; then
        _backup_all_namespaces $@
    else
        _backup_namespace $@
    fi
}

_prepare() {
    export NAMESPACE=${_NAMESPACE:-$(kubectl config view --minify --output 'jsonpath={..namespace}')}
    export BACKUP_DIR=$(pwd)/backups/$NAMESPACE/$(date +'%s')_$(date +'%Y-%m-%d_%H-%M-%S')
}

_backup_all_namespaces() {
    for n in $(kubectl get ns | tail -n +2 | cut -d' ' -f1); do
        export _NAMESPACE=$n
        _prepare
        ( _backup_namespace $@ ) || true
    done
}

_backup_namespace() {
    SECRETS="$(kubectl get secrets -n $NAMESPACE)"
    DEPLOYMENTS="$(kubectl get deployments -n $NAMESPACE)"
    if echo "$SECRETS" | grep -q postgres-postgres-secret; then
        mkdir -p $BACKUP_DIR
        echo "backing up namespace $NAMESPACE"
        sh ./scripts/backup/postgres.sh $@
        echo "backup completed for namespace $NAMESPACE"
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-d) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-l) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        mkdir -p $BACKUP_DIR
        echo "backing up namespace $NAMESPACE"
        sh ./scripts/backup/erpnext.sh $@
        echo "backup completed for namespace $NAMESPACE"
    elif (echo "$SECRETS" | grep -q openldap); then
        mkdir -p $BACKUP_DIR
        echo "backing up namespace $NAMESPACE"
        sh ./scripts/backup/openldap.sh $@
        echo "backup completed for namespace $NAMESPACE"
    else
        echo "no backup scripts for namespace $NAMESPACE" >&2
        exit 1
    fi
}

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            echo "rock8s backup - backup rock8s data"
            echo " "
            echo "rock8s backup [options]"
            echo " "
            echo "options:"
            echo "    -h, --help         show brief help"
            echo "    -n, --namespace    namespace to backup"
            echo "    -a, --all          backup all namespaces"
            exit 0
        ;;
        -n|--namespace)
            shift
            export _NAMESPACE=$1
            shift
        ;;
        -a|--all)
            shift
            export _ALL="1"
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
