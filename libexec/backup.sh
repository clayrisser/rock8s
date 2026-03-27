#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

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
       rock8s backup [-h] [-a|--all] [-o <format>] [-d <dir>] [--retries <n>] [--skip <components>] [--skip-volumes <pattern>] [--skip-namespaces <pattern>] [--no-skip-volumes] [namespace...]

DESCRIPTION
       backup cluster data and configurations

OPTIONS
       -h, --help
              show this help message

       -a, --all
              backup each namespace separately

       -o, --output=<format>
              output format (json, yaml, text)

       -d, --output-dir <dir>
              output directory for backups (default: $ROCK8S_CACHE_HOME/backups)

       --retries <n>
              number of retries for kubectl cp (default: 9)

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

_backup_volume_path() {
    _bvp_label="$1"
    _bvp_mount="$2"
    _bvp_outfile="$3"
    _bvp_est="$4"
    i=0
    while [ $i -lt $RETRIES ]; do
        i=$((i + 1))
        if [ $i -gt 1 ]; then
            warn "retrying backup of volume $_bvp_label $i/$RETRIES"
            sleep 1
        fi
        kubectl exec "$pod_name" -c "$container_name" -n "$NAMESPACE" -- /bin/sh -c "cd '$_bvp_mount' && tar cf - . 2>/dev/null | gzip -9" >"$_bvp_outfile" &
        pid=$!
        start_time=$(date +%s)
        while kill -0 $pid 2>/dev/null; do
            if [ -f "$_bvp_outfile" ]; then
                current_size=$(wc -c <"$_bvp_outfile" || echo 0)
                elapsed=$(($(date +%s) - start_time))
                [ $elapsed -eq 0 ] && rate=0 || rate=$((current_size / elapsed))
                percent=$((current_size * 100 / _bvp_est))
                show_progress "$_bvp_label" $current_size $_bvp_est $rate $percent
            fi
            sleep 1
        done
        wait $pid && return 0
        rm -f "$_bvp_outfile"
    done
    return 1
}

_backup_volumes() {
    cwd="$(pwd)"
    mkdir -p "$BACKUP_DIR/volumes"
    cd "$BACKUP_DIR/volumes"
    if [ "$_NO_SKIP_VOLUMES" = "1" ]; then
        _SKIP_VOLUMES=""
    else
        : "${_SKIP_VOLUMES:=(redis|cache|temp|tmp|logs|sessions|queue)}"
    fi
    for pvc in $(kubectl get pvc -n "$NAMESPACE" -o name | cut -d/ -f2); do
        if [ -n "$_SKIP_VOLUMES" ] && echo "$pvc" | grep -E -i -q "$_SKIP_VOLUMES"; then
            warn "skipping volume $NAMESPACE/$pvc"
            continue
        fi
        log "backing up volume $NAMESPACE/$pvc"
        pod_name=$(kubectl get pods -n "$NAMESPACE" -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | while read -r pod; do
            if kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.spec.volumes[*].persistentVolumeClaim.claimName}" | grep -q "^$pvc$"; then
                echo "$pod"
                break
            fi
        done)
        [ -z "$pod_name" ] && continue
        volume_name=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath="{.spec.volumes[?(@.persistentVolumeClaim.claimName=='$pvc')].name}")
        [ -z "$volume_name" ] && continue
        container_name=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath="{.spec.containers[0].name}")
        [ -z "$container_name" ] && continue
        mount_paths=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name=='$volume_name')].mountPath}")
        [ -z "$mount_paths" ] && continue
        valid_mount_paths=""
        valid_path_sizes=""
        valid_paths=0
        for mount_path in $mount_paths; do
            should_skip=0
            path_copy="$mount_path"
            while [ "$path_copy" != "/" ] && [ "$path_copy" != "." ]; do
                path_base=$(basename "$path_copy")
                if [ -n "$_SKIP_VOLUMES" ] && echo "$path_base" | grep -E -i -q "$_SKIP_VOLUMES"; then
                    warn "skipping mount path $NAMESPACE/$pvc:$mount_path (matched $path_base)"
                    should_skip=1
                    break
                fi
                path_copy=$(dirname "$path_copy")
            done
            [ $should_skip -eq 1 ] && continue
            raw_size=$(kubectl exec "$pod_name" -c "$container_name" -n "$NAMESPACE" -- sh -c "cd '$mount_path' && du -sb . | cut -f1" || echo 0)
            [ -z "$raw_size" ] && raw_size=0
            [ "$raw_size" -eq 0 ] && raw_size=1024
            valid_mount_paths="$valid_mount_paths $mount_path"
            valid_path_sizes="$valid_path_sizes $raw_size"
            valid_paths=$((valid_paths + 1))
        done
        [ $valid_paths -eq 0 ] && continue
        if [ $valid_paths -eq 1 ]; then
            mount_path=$(echo "$valid_mount_paths" | tr ' ' '\n' | head -n1)
            path_base=$(basename "$mount_path")
            raw_size=$(echo "$valid_path_sizes" | tr ' ' '\n' | head -n1)
            est_size=$((raw_size * 2 / 3))
            [ "$est_size" -lt 1024 ] && est_size=1024
            _backup_volume_path "$NAMESPACE/$pvc:$path_base" "$mount_path" "$pvc.tar.gz" "$est_size" ||
                fail "failed to backup volume $NAMESPACE/$pvc:$path_base"
        else
            temp_dir="$pvc.tmp"
            mkdir -p "$temp_dir"
            total_size=0
            index=1
            for mount_path in $valid_mount_paths; do
                path_base=$(basename "$mount_path")
                raw_size=$(echo "$valid_path_sizes" | cut -d' ' -f$index)
                est_size=$((raw_size * 2 / 3))
                [ "$est_size" -lt 1024 ] && est_size=1024
                _backup_volume_path "$NAMESPACE/$pvc:$path_base" "$mount_path" "$temp_dir/$path_base.tar.gz" "$est_size" || {
                    rm -rf "$temp_dir"
                    fail "failed to backup volume $NAMESPACE/$pvc:$path_base"
                }
                index=$((index + 1))
            done
            cd "$temp_dir"
            tar cf "../$pvc.tar.gz" --use-compress-program='gzip -9' .
            cd ..
            rm -rf "$temp_dir"
        fi
        final_size=$(wc -c <"$pvc.tar.gz")
        printf "\033[2K\r%s %s %s\n" "$NAMESPACE/$pvc" "████████████████████" "$(format_size $final_size)" >&2
    done
    cd "$cwd"
    [ -z "$(ls -A "$BACKUP_DIR/volumes" 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/volumes" || true
}

_backup_namespace() {
    cwd="$(pwd)"
    export NAMESPACE="$1"
    BACKUP_DIR="${_OUTPUT_DIR:-$ROCK8S_CACHE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME/$NAMESPACE"
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
    skip_volumes=0
    if (echo "$SECRETS" | grep -q postgres-postgres-secret) &&
        (echo "$DEPLOYMENTS" | grep -q 'postgres '); then
        . "$ROCK8S_LIB_PATH/backup/postgres.sh"
        skip_volumes=1
    elif (echo "$DEPLOYMENTS" | grep -q release-gunicorn) &&
        (echo "$DEPLOYMENTS" | grep -q release-worker-d) &&
        (echo "$DEPLOYMENTS" | grep -q release-worker-l) &&
        (echo "$DEPLOYMENTS" | grep -q release-worker-s); then
        . "$ROCK8S_LIB_PATH/backup/erpnext.sh"
        skip_volumes=1
    elif (echo "$SECRETS" | grep -q openldap); then
        . "$ROCK8S_LIB_PATH/backup/openldap.sh"
        skip_volumes=1
    elif (echo "$SECRETS" | grep -q mongodb) &&
        (kubectl get statefulset mongodb-rs0 -n "$NAMESPACE" >/dev/null 2>&1); then
        . "$ROCK8S_LIB_PATH/backup/mongo.sh"
        skip_volumes=1
    fi
    if [ $skip_volumes -eq 0 ] && ! echo "$_SKIP_COMPONENTS" | grep -q "volumes"; then
        _backup_volumes
    fi
    cd "$cwd"
    cd "${_OUTPUT_DIR:-$ROCK8S_CACHE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME"
    try "tar cf ${NAMESPACE}.tar.gz --use-compress-program='gzip -9' $NAMESPACE"
    cd "$cwd"
}

_backup_all_namespaces() {
    for n in $(kubectl get ns | tail -n +2 | cut -d' ' -f1); do
        if [ -n "$_SKIP_NAMESPACES" ] && echo "$n" | grep -E -i -q "$_SKIP_NAMESPACES"; then
            warn "skipping namespace $n"
            continue
        fi
        _backup_namespace "$n"
    done
    cd "${_OUTPUT_DIR:-$ROCK8S_CACHE_HOME/backups}/$KUBE_CONTEXT"
    try "tar cf $BACKUP_NAME.tar.gz --use-compress-program='gzip -1' -C $BACKUP_NAME *.tar.gz"
    printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespaces":%s}\n' \
        "$KUBE_CONTEXT" \
        "$BACKUP_NAME" \
        "${_OUTPUT_DIR:-$ROCK8S_CACHE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME.tar.gz" \
        "$(printf '%s' "$_NAMESPACES" | jq -R 'split(" ") | map(select(length > 0))')" |
        format_output "$_OUTPUT"
}

_backup_secrets() {
    mkdir -p "$BACKUP_DIR/secrets"
    kubectl get secrets -n "$NAMESPACE" 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        n=$(echo "$line" | awk '{print $1}')
        t=$(echo "$line" | awk '{print $2}')
        if [ "$t" != "helm.sh/release.v1" ]; then
            log "backing up secret $NAMESPACE/$n"
            try "kubectl get secret $n -n $NAMESPACE -o json" |
                jq 'if .data then .data |= map_values(@base64d) | .stringData = .data | del(.data) else . end | del(.metadata.creationTimestamp,.metadata.resourceVersion,.metadata.selfLink,.metadata.uid,.status)' |
                json2yaml >"$BACKUP_DIR/secrets/$n.yaml"
        fi
    done
    [ -z "$(ls -A "$BACKUP_DIR/secrets" 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/secrets" || true
}

_backup_configmaps() {
    mkdir -p "$BACKUP_DIR/configmaps"
    for n in $(kubectl get configmaps -n "$NAMESPACE" 2>/dev/null | tail -n +2 | cut -d' ' -f1); do
        log "backing up configmap $NAMESPACE/$n"
        try "kubectl get configmap $n -n $NAMESPACE -o yaml" |
            yaml2json |
            jq 'del(.metadata.creationTimestamp,.metadata.resourceVersion,.metadata.selfLink,.metadata.uid,.status)' |
            json2yaml >"$BACKUP_DIR/configmaps/$n.yaml"
    done
    [ -z "$(ls -A "$BACKUP_DIR/configmaps" 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/configmaps" || true
}

_backup_releases() {
    mkdir -p "$BACKUP_DIR/releases"
    for n in $(kubectl get helmreleases.helm.toolkit.fluxcd.io -n "$NAMESPACE" 2>/dev/null | tail -n +2 | cut -d' ' -f1); do
        log "backing up helm release $NAMESPACE/$n"
        try "kubectl get helmreleases.helm.toolkit.fluxcd.io $n -n $NAMESPACE -o yaml" |
            yaml2json |
            jq 'del(.metadata.creationTimestamp,.metadata.resourceVersion,.metadata.selfLink,.metadata.uid,.status)' |
            json2yaml >"$BACKUP_DIR/releases/$n.yaml"
    done
    [ -z "$(ls -A "$BACKUP_DIR/releases" 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/releases" || true
}

_backup_charts() {
    mkdir -p "$BACKUP_DIR/charts"
    for n in $(helm list -n "$NAMESPACE" -q 2>/dev/null || true); do
        log "backing up chart $NAMESPACE/$n"
        try "helm get all -n $NAMESPACE $n 2>/dev/null" | sed '/^MANIFEST:$/,$d' >"$BACKUP_DIR/charts/$n.yaml" || true
    done
    [ -z "$(ls -A "$BACKUP_DIR/charts" 2>/dev/null)" ] && rm -rf "$BACKUP_DIR/charts" || true
}

_main() {
    : "${RETRIES:=9}"
    command -v helm >/dev/null 2>&1 || {
        fail "helm is not installed"
    }
    _OUTPUT="${ROCK8S_OUTPUT:-text}"
    _OUTPUT_DIR=""
    all=""
    _NAMESPACES=""
    _SKIP_COMPONENTS=""
    _SKIP_VOLUMES=""
    _NO_SKIP_VOLUMES=""
    _SKIP_NAMESPACES=""
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            _help
            exit 0
            ;;
        -a | --all)
            all="1"
            shift
            ;;
        --skip | --skip=*)
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
        --skip-namespaces | --skip-namespaces=*)
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
        -o | --output | -o=* | --output=*)
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
        -d | --output-dir | -d=* | --output-dir=*)
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
        --retries | --retries=*)
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
        --skip-volumes | --skip-volumes=*)
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
    if [ "$all" = "1" ]; then
        _backup_all_namespaces
    elif [ -n "$_NAMESPACES" ]; then
        ns_count=$(printf '%s' "$_NAMESPACES" | wc -w)
        for n in $_NAMESPACES; do
            if ! kubectl get namespace "$n" >/dev/null 2>&1; then
                fail "namespace $n does not exist"
            fi
            _backup_namespace "$n"
        done
        if [ "$ns_count" -gt 1 ]; then
            cd "${_OUTPUT_DIR:-$ROCK8S_CACHE_HOME/backups}/$KUBE_CONTEXT"
            try "tar cf $BACKUP_NAME.tar.gz --use-compress-program='gzip -9' -C $BACKUP_NAME *.tar.gz"
            printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespaces":%s}\n' \
                "$KUBE_CONTEXT" \
                "$BACKUP_NAME" \
                "${_OUTPUT_DIR:-$ROCK8S_CACHE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME.tar.gz" \
                "$(printf '%s' "$_NAMESPACES" | jq -R 'split(" ") | map(select(length > 0))')" |
                format_output "$_OUTPUT"
        else
            printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespace":"%s"}\n' \
                "$KUBE_CONTEXT" \
                "$BACKUP_NAME" \
                "${_OUTPUT_DIR:-$ROCK8S_CACHE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME/${_NAMESPACES}.tar.gz" \
                "$(printf '%s' "$_NAMESPACES" | tr -d ' ')" |
                format_output "$_OUTPUT"
        fi
    else
        current_ns="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
        if [ -z "$current_ns" ]; then
            current_ns="default"
        fi
        if ! kubectl get namespace "$current_ns" >/dev/null 2>&1; then
            fail "current namespace $current_ns does not exist"
        fi
        _backup_namespace "$current_ns"
        printf '{"context":"%s","backup_name":"%s","backup_path":"%s","namespace":"%s"}\n' \
            "$KUBE_CONTEXT" \
            "$BACKUP_NAME" \
            "${_OUTPUT_DIR:-$ROCK8S_CACHE_HOME/backups}/$KUBE_CONTEXT/$BACKUP_NAME/${current_ns}.tar.gz" \
            "$current_ns" |
            format_output "$_OUTPUT"
    fi
}

_main "$@"
