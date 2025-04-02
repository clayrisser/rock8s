#!/bin/sh

set -e

YAML2JSON=$(which yq 2>&1 >/dev/null && \
    ((yq --version | grep -q "github.com/mikefarah/yq") && echo 'yq -o json' || echo yq) || \
    echo 'ruby -ryaml -rjson -e "puts JSON.pretty_generate(YAML.load(ARGF))"')
JSON2YAML=$(which yq 2>&1 >/dev/null && \
    ((yq --version | grep -q "github.com/mikefarah/yq") && echo 'yq eval -P' || echo 'yq -y') || \
    echo 'ruby -ryaml -rjson -e "puts YAML.dump(JSON.parse(STDIN.read))"')

main() {
    _prepare
    if [ "$_ALL" = "1" ]; then
        _backup_all_namespaces $@
    else
        _backup_namespace $@
    fi
}

_prepare() {
    export NAMESPACE="${_NAMESPACE:-$(kubectl config view --minify --output 'jsonpath={..namespace}')}"
    export BACKUP_NAME="$(date +'%s')_$(date +'%Y-%m-%d_%H-%M-%S')"
    export BACKUP_DIR="$(pwd)/backups/$NAMESPACE/$BACKUP_NAME"
}

_backup_all_namespaces() {
    for n in $(kubectl get ns | tail -n +2 | cut -d' ' -f1); do
        export _NAMESPACE=$n
        _prepare
        ( _backup_namespace $@ ) || true
    done
}

_backup_namespace() {
    SECRETS="$(kubectl get secrets -n $NAMESPACE 2>/dev/null)"
    DEPLOYMENTS="$(kubectl get deployments -n $NAMESPACE 2>/dev/null)"
    _backup_releases
    _backup_configmaps
    _backup_secrets
    if echo "$SECRETS" | grep -q postgres-postgres-secret; then
        mkdir -p $BACKUP_DIR
        echo "backing up namespace $NAMESPACE"
        sh ./scripts/backup/postgres.sh $@
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-d) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-l) && \
        (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        mkdir -p "$BACKUP_DIR"
        echo "backing up namespace $NAMESPACE"
        sh ./scripts/backup/erpnext.sh $@
    elif (echo "$SECRETS" | grep -q openldap); then
        mkdir -p "$BACKUP_DIR"
        echo "backing up namespace $NAMESPACE"
        sh ./scripts/backup/openldap.sh $@
    else
        echo "no backup scripts for namespace $NAMESPACE" >&2
    fi
    (cd "$BACKUP_DIR" && tar -czvf "$BACKUP_DIR.tar.gz" .)
    echo "backup completed for namespace $NAMESPACE"
}

_backup_secrets() {
    mkdir -p $BACKUP_DIR/secrets
    kubectl get secrets -n "$NAMESPACE" | tail -n +2 | while IFS= read -r line; do
        n=$(echo "$line" | awk '{print $1}')
        t=$(echo "$line" | awk '{print $2}')
        if [ "$t" != "helm.sh/release.v1" ]; then
            echo "backing up secret $NAMESPACE/$n"
            kubectl get -o json secret $n -n $NAMESPACE | \
                jq '.data |= map_values(@base64d) | .stringData = .data | del(.data, .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.selfLink, .metadata.uid, .status)' | \
                $JSON2YAML \
                > $BACKUP_DIR/secrets/$n.yaml
        fi
    done
}

_backup_configmaps() {
    mkdir -p $BACKUP_DIR/configmaps
    for n in $(kubectl get configmaps -n $NAMESPACE | tail -n +2 | cut -d' ' -f1); do
        echo "backing up configmap $NAMESPACE/$n"
        kubectl get -o yaml configmap $n -n $NAMESPACE > $BACKUP_DIR/configmaps/$n.yaml
    done
}

_backup_releases() {
    mkdir -p $BACKUP_DIR/releases
    for n in $(kubectl get helmreleases.helm.toolkit.fluxcd.io -n $NAMESPACE | tail -n +2 | cut -d' ' -f1); do
        echo "backing up helm release $NAMESPACE/$n"
        kubectl get -o yaml helmreleases.helm.toolkit.fluxcd.io $n -n $NAMESPACE > $BACKUP_DIR/releases/$n.yaml
    done
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
