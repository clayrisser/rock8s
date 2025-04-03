#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

handle_sigint() {
    kill -TERM -$$
    exit 130
}

trap handle_sigint INT

_help() {
    cat <<EOF >&2
NAME
       rock8s backup

SYNOPSIS
       rock8s backup [-h] [-n <namespace>] [-a] [-o <dir>] [--retries <n>]

DESCRIPTION
       backup cluster data and configurations

OPTIONS
       -h, --help
              show this help message

       -n, --namespace <namespace>
              namespace to backup (default: current namespace)

       -a, --all
              backup all namespaces

       -o, --output <dir>
              output directory for backups (default: $ROCK8S_STATE_HOME/backups)

       --retries <n>
              number of retries for kubectl cp (default: 3)

EXAMPLE
       # backup current namespace
       rock8s backup

       # backup specific namespace
       rock8s backup -n mynamespace

       # backup all namespaces
       rock8s backup -a

       # specify output directory
       rock8s backup -o /path/to/backups

       # specify number of retries
       rock8s backup --retries 5

SEE ALSO
       rock8s restore
              restore cluster data and configurations from backup
EOF
}

_backup_namespace() {
    NAMESPACE="${_NAMESPACE:-$(kubectl config view --minify --output 'jsonpath={..namespace}')}"
    KUBE_CONTEXT="$(kubectl config current-context)"
    BACKUP_DIR="${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME/$NAMESPACE"
    mkdir -p "$BACKUP_DIR"
    SECRETS="$(kubectl get secrets -n "$NAMESPACE" 2>/dev/null || true)"
    DEPLOYMENTS="$(kubectl get deployments -n "$NAMESPACE" 2>/dev/null || true)"
    (trap 'exit' INT; _backup_releases) &
    (trap 'exit' INT; _backup_configmaps) &
    (trap 'exit' INT; _backup_secrets) &
    (trap 'exit' INT; _backup_charts) &
    if echo "$SECRETS" | grep -q postgres-postgres-secret; then
        (trap 'exit' INT; . "$ROCK8S_LIB_PATH/libexec/backup/scripts/postgres.sh") &
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-d) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-l) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        (trap 'exit' INT; . "$ROCK8S_LIB_PATH/libexec/backup/scripts/erpnext.sh") &
    elif (echo "$SECRETS" | grep -q openldap); then
        (trap 'exit' INT; . "$ROCK8S_LIB_PATH/libexec/backup/scripts/openldap.sh") &
    fi
    wait
}

_remove_empty_folders() {
    find "$1" -type d -empty -delete
}

_backup_all_namespaces() {
    for n in $(kubectl get ns | tail -n +2 | cut -d' ' -f1); do
        _NAMESPACE=$n
        (_backup_namespace) || true
    done
    KUBE_CONTEXT="$(kubectl config current-context)"
    _remove_empty_folders "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME"
    (cd "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT" && try tar -czf "$BACKUP_NAME.tar.gz" -C "$BACKUP_NAME" .)
    echo "backup completed"
}

_backup_secrets() {
    mkdir -p "$BACKUP_DIR/secrets"
    kubectl get secrets -n "$NAMESPACE" 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        _N=$(echo "$line" | awk '{print $1}')
        _T=$(echo "$line" | awk '{print $2}')
        if [ "$_T" != "helm.sh/release.v1" ]; then
            echo "backing up secret $NAMESPACE/$_N"
            try kubectl get secret "$_N" -n "$NAMESPACE" -o json | \
                jq 'if .data then .data |= map_values(@base64d) | .stringData = .data | del(.data) else . end | del(.metadata.creationTimestamp,.metadata.resourceVersion,.metadata.selfLink,.metadata.uid,.status)' | \
                json2yaml > "$BACKUP_DIR/secrets/$_N.yaml"
        fi
    done
    [ -z "$(ls -A $BACKUP_DIR/secrets 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/secrets" || true
}

_backup_configmaps() {
    mkdir -p "$BACKUP_DIR/configmaps"
    for _N in $(kubectl get configmaps -n "$NAMESPACE" 2>/dev/null | tail -n +2 | cut -d' ' -f1); do
        echo "backing up configmap $NAMESPACE/$_N"
        try kubectl get configmap "$_N" -n "$NAMESPACE" -o yaml | \
            yaml2json | \
            jq 'del(.metadata.creationTimestamp,.metadata.resourceVersion,.metadata.selfLink,.metadata.uid,.status)' | \
            json2yaml > "$BACKUP_DIR/configmaps/$_N.yaml"
    done
    [ -z "$(ls -A $BACKUP_DIR/configmaps 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/configmaps" || true
}

_backup_releases() {
    mkdir -p "$BACKUP_DIR/releases"
    for _N in $(kubectl get helmreleases.helm.toolkit.fluxcd.io -n "$NAMESPACE" 2>/dev/null | tail -n +2 | cut -d' ' -f1); do
        echo "backing up helm release $NAMESPACE/$_N"
        try kubectl get helmreleases.helm.toolkit.fluxcd.io "$_N" -n "$NAMESPACE" -o yaml | \
            yaml2json | \
            jq 'del(.metadata.creationTimestamp,.metadata.resourceVersion,.metadata.selfLink,.metadata.uid,.status)' | \
            json2yaml > "$BACKUP_DIR/releases/$_N.yaml"
    done
    [ -z "$(ls -A $BACKUP_DIR/releases 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/releases" || true
}

_backup_charts() {
    mkdir -p "$BACKUP_DIR/charts"
    if ! helm list -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "no helm releases found in namespace $NAMESPACE"
        rm -rf "$BACKUP_DIR/charts"
        return
    fi
    for _N in $(helm list -n "$NAMESPACE" -q 2>/dev/null || true); do
        echo "backing up chart $NAMESPACE/$_N"
        try helm get all -n "$NAMESPACE" "$_N" 2>/dev/null | sed '/^MANIFEST:$/,$d' > "$BACKUP_DIR/charts/$_N.yaml" || true
    done
    [ -z "$(ls -A $BACKUP_DIR/charts 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/charts" || true
}

_main() {
    : "${RETRIES:=9}"
    command -v helm >/dev/null 2>&1 || {
        fail "helm is not installed"
    }
    _NAMESPACE=""
    _OUTPUT_DIR=""
    _ALL=""
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
            -a|--all)
                _ALL="1"
                shift
                ;;
            -o|--output|-o=*|--output=*)
                case "$1" in
                    *=*)
                        _OUTPUT_DIR="${1#*=}"
                        shift
                        ;;
                    *)
                        _OUTPUT_DIR="$2"
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
    export RETRIES
    export BACKUP_NAME="$(date +'%s')_$(date +'%Y-%m-%d_%H-%M-%S')"
    export KUBE_CONTEXT="$(kubectl config current-context)"
    if [ "$_ALL" = "1" ]; then
        _backup_all_namespaces
    else
        _backup_namespace
        _remove_empty_folders "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME"
        (cd "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT" && try tar -czf "$BACKUP_NAME.tar.gz" -C "$BACKUP_NAME" .)
    fi
}

_main "$@"
