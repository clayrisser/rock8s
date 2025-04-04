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
       rock8s backup [-h] [-b|--bundle] [-a|--all] [-o <format>] [-d <dir>] [--retries <n>] [--skip <components>] [--skip-volumes <pattern>] [--skip-namespaces <pattern>] [--no-skip-volumes] [namespace...]

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

       --skip-volumes <pattern>
              regex pattern for volume names to skip (default: redis|cache|temp|tmp|logs|sessions|queue)

       --skip-namespaces <pattern>
              regex pattern for namespaces to skip when using --all (default: olm|operators|kube-node-lease|flux-system|cattle-monitoring-system)

       --no-skip-volumes
              disable default volume skipping behavior

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
    if [ "$_NO_SKIP_VOLUMES" = "1" ]; then
        _SKIP_VOLUMES=""
    else
        : "${_SKIP_VOLUMES:=(redis|cache|temp|tmp|logs|sessions|queue)}"
    fi
    for _PVC in $(kubectl get pvc -n "$NAMESPACE" -o name | cut -d/ -f2);do
        if [ -n "$_SKIP_VOLUMES" ] && echo "$_PVC" | grep -E -i -q "$_SKIP_VOLUMES";then
            warn "skipping volume $NAMESPACE/$_PVC"
            continue
        fi
        log "backing up volume $NAMESPACE/$_PVC"
        _ESCAPED_PVC=$(echo "$_PVC" | sed -e 's/\./\\./g')
        _POD_NAME=$(kubectl get pods -n "$NAMESPACE" -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | while read -r pod; do
            if kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.spec.volumes[*].persistentVolumeClaim.claimName}" | grep -q "^$_PVC$"; then
                echo "$pod"
                break
            fi
        done)
        [ -z "$_POD_NAME" ] && continue
        _VOLUME_NAME=$(kubectl get pod "$_POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.volumes[?(@.persistentVolumeClaim.claimName=='$_PVC')].name}")
        [ -z "$_VOLUME_NAME" ] && continue
        _CONTAINER_NAME=$(kubectl get pod "$_POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[0].name}")
        [ -z "$_CONTAINER_NAME" ] && continue
        _MOUNT_PATHS=$(kubectl get pod "$_POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name=='$_VOLUME_NAME')].mountPath}")
        [ -z "$_MOUNT_PATHS" ] && continue
        _VALID_MOUNT_PATHS=""
        _VALID_PATH_SIZES=""
        _VALID_PATHS=0
        for _MOUNT_PATH in $_MOUNT_PATHS; do
            _SHOULD_SKIP=0
            _PATH_COPY="$_MOUNT_PATH"
            while [ "$_PATH_COPY" != "/" ] && [ "$_PATH_COPY" != "." ]; do
                _PATH_BASE=$(basename "$_PATH_COPY")
                if [ -n "$_SKIP_VOLUMES" ] && echo "$_PATH_BASE"|grep -E -i -q "$_SKIP_VOLUMES";then
                    warn "skipping mount path $NAMESPACE/$_PVC:$_MOUNT_PATH (matched $_PATH_BASE)"
                    _SHOULD_SKIP=1
                    break
                fi
                _PATH_COPY=$(dirname "$_PATH_COPY")
            done
            [ $_SHOULD_SKIP -eq 1 ] && continue
            _RAW_SIZE=$(kubectl exec "$_POD_NAME" -c "$_CONTAINER_NAME" -n "$NAMESPACE" -- sh -c "cd '$_MOUNT_PATH' && du -sb . | cut -f1" || echo 0)
            [ -z "$_RAW_SIZE" ] && _RAW_SIZE=0
            [ "$_RAW_SIZE" -eq 0 ] && _RAW_SIZE=1024
            _VALID_MOUNT_PATHS="$_VALID_MOUNT_PATHS $_MOUNT_PATH"
            _VALID_PATH_SIZES="$_VALID_PATH_SIZES $_RAW_SIZE"
            _VALID_PATHS=$((_VALID_PATHS + 1))
        done
        [ $_VALID_PATHS -eq 0 ] && continue
        if [ $_VALID_PATHS -eq 1 ]; then
            _MOUNT_PATH=$(echo "$_VALID_MOUNT_PATHS" | tr ' ' '\n' | head -n1)
            _PATH_BASE=$(basename "$_MOUNT_PATH")
            _RAW_SIZE=$(echo "$_VALID_PATH_SIZES" | tr ' ' '\n' | head -n1)
            _EST_SIZE=$((_RAW_SIZE * 2 / 3))
            [ "$_EST_SIZE" -lt 1024 ] && _EST_SIZE=1024
            _I=0
            while [ $_I -lt $RETRIES ]; do
                _I=$((_I+1))
                if [ $_I -gt 1 ]; then
                    warn "retrying backup of volume $NAMESPACE/$_PVC:$_PATH_BASE $_I/$RETRIES"
                    sleep 1
                fi
                kubectl exec "$_POD_NAME" -c "$_CONTAINER_NAME" -n "$NAMESPACE" -- /bin/sh -c "cd '$_MOUNT_PATH' && tar cf - . 2>/dev/null | gzip -9" > "$_PVC.tar.gz" &
                _PID=$!
                _START_TIME=$(date +%s)
                _LAST_SIZE=0
                while kill -0 $_PID 2>/dev/null; do
                    if [ -f "$_PVC.tar.gz" ]; then
                        _CURRENT_SIZE=$(wc -c < "$_PVC.tar.gz" || echo 0)
                        _ELAPSED=$(($(date +%s) - _START_TIME))
                        [ $_ELAPSED -eq 0 ] && _RATE=0 || _RATE=$((_CURRENT_SIZE / _ELAPSED))
                        _PERCENT=$((_CURRENT_SIZE * 100 / _EST_SIZE))
                        [ $_PERCENT -gt 100 ] && _PERCENT=99
                        show_progress "$NAMESPACE/$_PVC:$_PATH_BASE" $_CURRENT_SIZE $_EST_SIZE $_RATE $_PERCENT
                        _LAST_SIZE=$_CURRENT_SIZE
                    fi
                    sleep 1
                done
                wait $_PID
                if [ $? -eq 0 ]; then
                    break
                fi
                rm -f "$_PVC.tar.gz"
            done
            if [ $_I -eq $RETRIES ]; then
                fail "failed to backup volume $NAMESPACE/$_PVC:$_PATH_BASE"
            fi
        else
            _TEMP_DIR="$_PVC.tmp"
            mkdir -p "$_TEMP_DIR"
            _TOTAL_SIZE=0
            _INDEX=1
            for _MOUNT_PATH in $_VALID_MOUNT_PATHS; do
                _PATH_BASE=$(basename "$_MOUNT_PATH")
                _RAW_SIZE=$(echo "$_VALID_PATH_SIZES" | cut -d' ' -f$_INDEX)
                _EST_SIZE=$((_RAW_SIZE * 2 / 3))
                [ "$_EST_SIZE" -lt 1024 ] && _EST_SIZE=1024
                _I=0
                while [ $_I -lt $RETRIES ]; do
                    _I=$((_I+1))
                    if [ $_I -gt 1 ]; then
                        warn "retrying backup of volume $NAMESPACE/$_PVC:$_PATH_BASE $_I/$RETRIES"
                        sleep 1
                    fi
                    kubectl exec "$_POD_NAME" -c "$_CONTAINER_NAME" -n "$NAMESPACE" -- /bin/sh -c "cd '$_MOUNT_PATH' && tar cf - . 2>/dev/null | gzip -9" > "$_TEMP_DIR/$_PATH_BASE.tar.gz" &
                    _PID=$!
                    _START_TIME=$(date +%s)
                    _LAST_SIZE=0
                    while kill -0 $_PID 2>/dev/null; do
                        if [ -f "$_TEMP_DIR/$_PATH_BASE.tar.gz" ]; then
                            _CURRENT_SIZE=$(wc -c < "$_TEMP_DIR/$_PATH_BASE.tar.gz" || echo 0)
                            _ELAPSED=$(($(date +%s) - _START_TIME))
                            [ $_ELAPSED -eq 0 ] && _RATE=0 || _RATE=$((_CURRENT_SIZE / _ELAPSED))
                            _PERCENT=$((_CURRENT_SIZE * 100 / _EST_SIZE))
                            [ $_PERCENT -gt 100 ] && _PERCENT=99
                            show_progress "$NAMESPACE/$_PVC:$_PATH_BASE" $_CURRENT_SIZE $_EST_SIZE $_RATE $_PERCENT
                            _LAST_SIZE=$_CURRENT_SIZE
                        fi
                        sleep 1
                    done
                    wait $_PID
                    if [ $? -eq 0 ]; then
                        break
                    fi
                    rm -f "$_TEMP_DIR/$_PATH_BASE.tar.gz"
                done
                if [ $_I -eq $RETRIES ]; then
                    rm -rf "$_TEMP_DIR"
                    fail "failed to backup volume $NAMESPACE/$_PVC:$_PATH_BASE"
                fi
                _INDEX=$((_INDEX + 1))
            done
            cd "$_TEMP_DIR"
            tar cf "../$_PVC.tar.gz" --use-compress-program='gzip -9' .
            cd ..
            rm -rf "$_TEMP_DIR"
        fi
        _FINAL_SIZE=$(wc -c < "$_PVC.tar.gz")
        printf "\033[2K\r%s %s %s\n" "$NAMESPACE/$_PVC" "████████████████████" "$(format_size $_FINAL_SIZE)" >&2
    done
    cd "$_CWD"
    [ -z "$(ls -A "$BACKUP_DIR/volumes" 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/volumes" || true
}

_backup_namespace() {
    _CWD="$(pwd)"
    export NAMESPACE="$1"
    KUBE_CONTEXT="$(kubectl config current-context)"
    BACKUP_DIR="${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME/$NAMESPACE"
    mkdir -p "$BACKUP_DIR"
    SECRETS="$(kubectl get secrets -n "$NAMESPACE" 2>/dev/null || true)"
    DEPLOYMENTS="$(kubectl get deployments -n "$NAMESPACE" 2>/dev/null || true)"
    if ! echo "$_SKIP_COMPONENTS" | grep -q "releases"; then
        _backup_releases
    fi
    if ! echo "$_SKIP_COMPONENTS" | grep -q "configmaps"; then
        _backup_configmaps
    fi
    if ! echo "$_SKIP_COMPONENTS" | grep -q "secrets"; then
        _backup_secrets
    fi
    if ! echo "$_SKIP_COMPONENTS" | grep -q "charts"; then
        _backup_charts
    fi
    _SKIP_VOLUMES=0
    if (echo "$SECRETS" | grep -q postgres-postgres-secret) && \
       (echo "$DEPLOYMENTS" | grep -q 'postgres '); then
        . "$ROCK8S_LIB_PATH/libexec/backup/scripts/postgres.sh"
        _SKIP_VOLUMES=1
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-d) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-l) && \
         (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        . "$ROCK8S_LIB_PATH/libexec/backup/scripts/erpnext.sh"
        _SKIP_VOLUMES=1
    elif (echo "$SECRETS" | grep -q openldap); then
        . "$ROCK8S_LIB_PATH/libexec/backup/scripts/openldap.sh"
        _SKIP_VOLUMES=1
    elif (echo "$SECRETS" | grep -q mongodb) && \
         (kubectl get statefulset mongodb-rs0 -n "$NAMESPACE" >/dev/null 2>&1); then
        . "$ROCK8S_LIB_PATH/libexec/backup/scripts/mongo.sh"
        _SKIP_VOLUMES=1
    fi
    if [ $_SKIP_VOLUMES -eq 0 ] && ! echo "$_SKIP_COMPONENTS" | grep -q "volumes"; then
        _backup_volumes
    fi
    cd "$_CWD"
    cd "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME"
    try "tar cf ${NAMESPACE}.tar.gz --use-compress-program='gzip -9' $NAMESPACE"
}

_backup_all_namespaces() {
    for _N in $(kubectl get ns | tail -n +2 | cut -d' ' -f1); do
        if [ -n "$_SKIP_NAMESPACES" ] && echo "$_N" | grep -E -i -q "$_SKIP_NAMESPACES"; then
            warn "skipping namespace $_N"
            continue
        fi
        _backup_namespace "$_N"
    done
    cd "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT"
    try "tar cf $BACKUP_NAME.tar.gz --use-compress-program='gzip -1' -C $BACKUP_NAME *.tar.gz"
    printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespaces":%s}\n' \
        "$KUBE_CONTEXT" \
        "$BACKUP_NAME" \
        "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME.tar.gz" \
        "$(printf '%s' "$_NAMESPACES" | jq -R 'split(" ") | map(select(length > 0))')" \
        | format_output "$_OUTPUT"
}

_backup_secrets() {
    mkdir -p "$BACKUP_DIR/secrets"
    kubectl get secrets -n "$NAMESPACE" 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        _N=$(echo "$line" | awk '{print $1}')
        _T=$(echo "$line" | awk '{print $2}')
        if [ "$_T" != "helm.sh/release.v1" ]; then
            log "backing up secret $NAMESPACE/$_N"
            try "kubectl get secret $_N -n $NAMESPACE -o json" | \
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
        try "kubectl get configmap $_N -n $NAMESPACE -o yaml" | \
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
        try "kubectl get helmreleases.helm.toolkit.fluxcd.io $_N -n $NAMESPACE -o yaml" | \
            yaml2json | \
            jq 'del(.metadata.creationTimestamp,.metadata.resourceVersion,.metadata.selfLink,.metadata.uid,.status)' | \
            json2yaml > "$BACKUP_DIR/releases/$_N.yaml"
    done
    [ -z "$(ls -A $BACKUP_DIR/releases 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/releases" || true
}

_backup_charts() {
    mkdir -p "$BACKUP_DIR/charts"
    for _N in $(helm list -n "$NAMESPACE" -q 2>/dev/null || true); do
        log "backing up chart $NAMESPACE/$_N"
        try "helm get all -n $NAMESPACE $_N 2>/dev/null" | sed '/^MANIFEST:$/,$d' > "$BACKUP_DIR/charts/$_N.yaml" || true
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
    _NAMESPACES=""
    _SKIP_COMPONENTS=""
    _SKIP_VOLUMES=""
    _NO_SKIP_VOLUMES=""
    _SKIP_NAMESPACES=""
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
            --skip-namespaces|--skip-namespaces=*)
                case "$1" in
                    *=*)
                        _SKIP_NAMESPACES="${1#*=}"
                        shift
                        ;;
                    *)
                        _SKIP_NAMESPACES="$2"
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
            --skip-volumes|--skip-volumes=*)
                case "$1" in
                    *=*)
                        _SKIP_VOLUMES="${1#*=}"
                        shift
                        ;;
                    *)
                        _SKIP_VOLUMES="$2"
                        shift 2
                        ;;
                esac
                ;;
            --no-skip-volumes)
                _NO_SKIP_VOLUMES="1"
                shift
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
        _NS_COUNT=$(printf '%s' "$_NAMESPACES" | wc -w)
        for _N in $_NAMESPACES; do
            if ! kubectl get namespace "$_N" >/dev/null 2>&1; then
                fail "namespace $_N does not exist"
            fi
            _backup_namespace "$_N"
        done
        if [ "$_NS_COUNT" -gt 1 ]; then
            cd "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT"
            try "tar cf $BACKUP_NAME.tar.gz --use-compress-program='gzip -9' -C $BACKUP_NAME *.tar.gz"
            printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespaces":%s}\n' \
                "$KUBE_CONTEXT" \
                "$BACKUP_NAME" \
                "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME.tar.gz" \
                "$(printf '%s' "$_NAMESPACES" | jq -R 'split(" ") | map(select(length > 0))')" \
                | format_output "$_OUTPUT"
        else
            printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespace":"%s"}\n' \
                "$KUBE_CONTEXT" \
                "$BACKUP_NAME" \
                "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME/${_NAMESPACES}.tar.gz" \
                "$(printf '%s' "$_NAMESPACES" | tr -d ' ')" \
                | format_output "$_OUTPUT"
        fi
    else
        _CURRENT_NS="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
        if [ -z "$_CURRENT_NS" ]; then
            _CURRENT_NS="default"
        fi
        if ! kubectl get namespace "$_CURRENT_NS" >/dev/null 2>&1; then
            fail "current namespace $_CURRENT_NS does not exist"
        fi
        _backup_namespace "$_CURRENT_NS"
        printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespace":"%s"}\n' \
            "$KUBE_CONTEXT" \
            "$BACKUP_NAME" \
            "${_OUTPUT_DIR:-$ROCK8S_STATE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME/${_CURRENT_NS}.tar.gz" \
            "$_CURRENT_NS" \
            | format_output "$_OUTPUT"
    fi
}

_main "$@"
