#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

handle_sigint() {
    trap - INT
    kill -TERM 0
    exit 130
}

trap handle_sigint INT

_help() {
    cat <<EOF >&2
NAME
       rock8s backup

SYNOPSIS
       rock8s backup [-h] [-b|--bundle] [-a|--all] [-o <format>] [-d|--output-dir <dir>] [--retries <n>] [--skip <components>] [namespace...]

DESCRIPTION
       backup cluster data and configurations

OPTIONS
       -h, --help
              show this help message

       -b, --bundle
              bundle specified namespaces into a single backup (or all namespaces if none specified)

       -a, --all
              backup each namespace separately

       -o, --output=<format>
              output format (json, yaml, text)

       -d, --output-dir <dir>
              output directory for backups (default: $ROCK8S_STATE_HOME/backups)

       --retries <n>
              number of retries for kubectl cp (default: 3)

       --skip <components>
              comma-separated list of components to skip (configmaps,charts,secrets,releases,volumes)

ARGUMENTS
       namespace...
              namespaces to backup (default: current namespace)

EXAMPLE
       # backup current namespace
       rock8s backup

       # backup specific namespaces separately
       rock8s backup namespace1 namespace2

       # bundle specific namespaces
       rock8s backup -b namespace1 namespace2

       # backup all namespaces into a single bundle
       rock8s backup -b

       # backup each namespace separately
       rock8s backup -a

       # specify output directory
       rock8s backup -d /path/to/backups

       # specify output format
       rock8s backup -o json

       # specify number of retries
       rock8s backup --retries 5

SEE ALSO
       rock8s restore
              restore cluster data and configurations from backup
EOF
}

_backup_volumes() {
    _CWD="$(pwd)"
    mkdir -p "$BACKUP_DIR/volumes"
    cd "$BACKUP_DIR/volumes"
    for _PVC in $(kubectl get pvc -n "$NAMESPACE" -o name | cut -d/ -f2); do
        log "backing up volume $NAMESPACE/$_PVC"
        _POD_NAME=$(kubectl get pods -n "$NAMESPACE" -o jsonpath="{.items[?(@.spec.volumes[*].persistentVolumeClaim.claimName=='$_PVC')].metadata.name}")
        [ -z "$_POD_NAME" ] && continue
        _VOLUME_NAME=$(kubectl get pod "$_POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.volumes[?(@.persistentVolumeClaim.claimName=='$_PVC')].name}")
        [ -z "$_VOLUME_NAME" ] && continue
        _CONTAINER_NAME=$(kubectl get pod "$_POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[0].name}")
        [ -z "$_CONTAINER_NAME" ] && continue
        _MOUNT_PATH=$(kubectl get pod "$_POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name=='$_VOLUME_NAME')].mountPath}")
        [ -z "$_MOUNT_PATH" ] && continue
        _RAW_SIZE=$(kubectl exec "$_POD_NAME" -c "$_CONTAINER_NAME" -n "$NAMESPACE" -- sh -c "cd '$_MOUNT_PATH' && du -sb . | cut -f1")
        _EST_SIZE=$((_RAW_SIZE / 10))
        rm -f "$_PVC.tar.gz"
        (kubectl exec "$_POD_NAME" -c "$_CONTAINER_NAME" -n "$NAMESPACE" -- /bin/sh -c "cd '$_MOUNT_PATH' && tar -cf - . 2>/dev/null | gzip -9" > "$_PVC.tar.gz") &
        _PID=$!
        _START_TIME=$(date +%s)
        _LAST_SIZE=0
        while ! [ -f "$_PVC.tar.gz" ]; do
            sleep 1
        done
        while kill -0 $_PID 2>/dev/null; do
            _CURRENT_SIZE=$(wc -c < "$_PVC.tar.gz")
            if [ $_CURRENT_SIZE -gt $_LAST_SIZE ]; then
                _ELAPSED=$(($(date +%s) - _START_TIME))
                [ $_ELAPSED -eq 0 ] && _RATE=0 || _RATE=$((_CURRENT_SIZE / _ELAPSED))
                _PERCENT=$((_CURRENT_SIZE * 100 / _EST_SIZE))
                show_progress "$NAMESPACE/$_PVC" $_CURRENT_SIZE $_EST_SIZE $_RATE $_PERCENT
                _LAST_SIZE=$_CURRENT_SIZE
            fi
            sleep 1
        done
        wait $_PID || {
            log "failed to backup volume $NAMESPACE/$_PVC"
            continue
        }
        _FINAL_SIZE=$(wc -c < "$_PVC.tar.gz")
        printf "\033[2K\r%s %s %s\n" "$NAMESPACE/$_PVC" "████████████████████" "$(format_size $_FINAL_SIZE)" >&2
    done
    cd "$_CWD"
    [ -z "$(ls -A "$BACKUP_DIR/volumes" 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/volumes"
    return
}

_backup_namespace() {
    export NAMESPACE="$1"
    KUBE_CONTEXT="$(kubectl config current-context)"
    BACKUP_DIR="${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME/$NAMESPACE"
    mkdir -p "$BACKUP_DIR"
    SECRETS="$(kubectl get secrets -n "$NAMESPACE" 2>/dev/null || true)"
    DEPLOYMENTS="$(kubectl get deployments -n "$NAMESPACE" 2>/dev/null || true)"
    if ! echo "$_SKIP_COMPONENTS" | grep -q "releases"; then
        (trap 'exit' INT; _backup_releases) &
    fi
    if ! echo "$_SKIP_COMPONENTS" | grep -q "configmaps"; then
        (trap 'exit' INT; _backup_configmaps) &
    fi
    if ! echo "$_SKIP_COMPONENTS" | grep -q "secrets"; then
        (trap 'exit' INT; _backup_secrets) &
    fi
    if ! echo "$_SKIP_COMPONENTS" | grep -q "charts"; then
        (trap 'exit' INT; _backup_charts) &
    fi
    wait
    _SKIP_VOLUMES=0
    if echo "$SECRETS" | grep -q postgres-postgres-secret; then
        (trap 'exit' INT; . "$ROCK8S_LIB_PATH/libexec/backup/scripts/postgres.sh") &
        _SKIP_VOLUMES=1
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-d) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-l) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        (trap 'exit' INT; . "$ROCK8S_LIB_PATH/libexec/backup/scripts/erpnext.sh") &
        _SKIP_VOLUMES=1
    elif (echo "$SECRETS" | grep -q openldap); then
        (trap 'exit' INT; . "$ROCK8S_LIB_PATH/libexec/backup/scripts/openldap.sh") &
        _SKIP_VOLUMES=1
    elif (echo "$SECRETS" | grep -q mongodb) && \
         (kubectl get statefulset mongodb-rs0 -n "$NAMESPACE" >/dev/null 2>&1); then
        (trap 'exit' INT; . "$ROCK8S_LIB_PATH/libexec/backup/scripts/mongo.sh") &
        _SKIP_VOLUMES=1
    fi
    wait
    if [ $_SKIP_VOLUMES -eq 0 ] && ! echo "$_SKIP_COMPONENTS" | grep -q "volumes"; then
        (trap 'exit' INT; _backup_volumes)
    fi
}

_remove_empty_folders() {
    _DIR="$1"
    [ -z "$_DIR" ] && return 1
    find "$_DIR" -type d -empty -not -path "*/volumes/*" -not -path "$_DIR" -delete
    return 0
}

_backup_all_namespaces() {
    for n in $(kubectl get ns | tail -n +2 | cut -d' ' -f1); do
        (_backup_namespace "$n") || true
    done
    KUBE_CONTEXT="$(kubectl config current-context)"
    _remove_empty_folders "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME"
    if [ "$_BUNDLE" = "1" ]; then
        cd "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT"
        sleep 1
        try "tar czf $BACKUP_NAME.tar.gz -C $BACKUP_NAME ."
    fi
    printf '{"context":"%s","backup_name":"%s","backup_path":"%s","type":"all_namespaces","bundle":%s}\n' \
        "$KUBE_CONTEXT" \
        "$BACKUP_NAME" \
        "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME" \
        "${_BUNDLE:-0}" | format_output "$_OUTPUT"
}

_backup_secrets() {
    mkdir -p "$BACKUP_DIR/secrets"
    kubectl get secrets -n "$NAMESPACE" 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        _N=$(echo "$line" | awk '{print $1}')
        _T=$(echo "$line" | awk '{print $2}')
        if [ "$_T" != "helm.sh/release.v1" ]; then
            log "backing up secret $NAMESPACE/$_N"
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
        log "backing up configmap $NAMESPACE/$_N"
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
        log "backing up helm release $NAMESPACE/$_N"
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
        log "no helm releases found in namespace $NAMESPACE"
        rm -rf "$BACKUP_DIR/charts"
        return
    fi
    for _N in $(helm list -n "$NAMESPACE" -q 2>/dev/null || true); do
        log "backing up chart $NAMESPACE/$_N"
        try helm get all -n "$NAMESPACE" "$_N" 2>/dev/null | sed '/^MANIFEST:$/,$d' > "$BACKUP_DIR/charts/$_N.yaml" || true
    done
    [ -z "$(ls -A $BACKUP_DIR/charts 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/charts" || true
}

_main() {
    : "${RETRIES:=9}"
    command -v helm >/dev/null 2>&1 || {
        fail "helm is not installed"
    }
    _OUTPUT="${ROCK8S_OUTPUT:-text}"
    _OUTPUT_DIR=""
    _ALL=""
    _BUNDLE=""
    _NAMESPACES=""
    _SKIP_COMPONENTS=""
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
                ;;
            -a|--all)
                _ALL="1"
                shift
                ;;
            -b|--bundle)
                _BUNDLE="1"
                shift
                ;;
            --skip|--skip=*)
                case "$1" in
                    *=*)
                        _SKIP_COMPONENTS="${1#*=}"
                        shift
                        ;;
                    *)
                        _SKIP_COMPONENTS="$2"
                        shift 2
                        ;;
                esac
                ;;
            -o|--output|-o=*|--output=*)
                case "$1" in
                    *=*)
                        _OUTPUT="${1#*=}"
                        shift
                        ;;
                    *)
                        _OUTPUT="$2"
                        shift 2
                        ;;
                esac
                ;;
            -d|--output-dir|-d=*|--output-dir=*)
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
                _NAMESPACES="$_NAMESPACES $1"
                shift
                ;;
        esac
    done
    export RETRIES
    export BACKUP_NAME="$(date +'%s')_$(date +'%Y-%m-%d_%H-%M-%S')"
    export KUBE_CONTEXT="$(kubectl config current-context)"
    if [ "$_ALL" = "1" ]; then
        _backup_all_namespaces
    elif [ -n "$_NAMESPACES" ]; then
        for ns in $_NAMESPACES; do
            if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
                fail "namespace $ns does not exist"
            fi
            (_backup_namespace "$ns") || true
        done
        _remove_empty_folders "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME"
        if [ "$_BUNDLE" = "1" ]; then
            cd "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT"
            sleep 1
            try "tar czf $BACKUP_NAME.tar.gz -C $BACKUP_NAME ."
        fi
        printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespaces":%s}\n' \
            "$KUBE_CONTEXT" \
            "$BACKUP_NAME" \
            "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME" \
            "$(printf '%s' "$_NAMESPACES" | jq -R 'split(" ") | map(select(length > 0))')" \
            | format_output "$_OUTPUT"
    else
        _CURRENT_NS="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
        if [ -z "$_CURRENT_NS" ]; then
            fail "no namespace specified and no current namespace set"
        fi
        if ! kubectl get namespace "$_CURRENT_NS" >/dev/null 2>&1; then
            fail "current namespace $_CURRENT_NS does not exist"
        fi
        (_backup_namespace "$_CURRENT_NS") || true
        _remove_empty_folders "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME"
        if [ "$_BUNDLE" = "1" ]; then
            cd "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT"
            sleep 1
            try "tar czf $BACKUP_NAME.tar.gz -C $BACKUP_NAME ."
        fi
        printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespace":"%s"}\n' \
            "$KUBE_CONTEXT" \
            "$BACKUP_NAME" \
            "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME" \
            "$_CURRENT_NS" \
            | format_output "$_OUTPUT"
    fi
}

_main "$@"
