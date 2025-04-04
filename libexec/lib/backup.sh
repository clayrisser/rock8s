#!/bin/sh

set -e

backup_download_with_progress() {
    _POD_NAME="$1"
    _NAMESPACE="$2"
    _CONTAINER="$3"
    _REMOTE_PATH="$4"
    _LOCAL_PATH="$5"
    _DISPLAY_NAME="$6"
    _CMD="kubectl exec $_POD_NAME -n $_NAMESPACE"
    if [ -n "$_CONTAINER" ]; then
        _CMD="$_CMD -c $_CONTAINER"
    fi
    SIZE=$($_CMD -- sh -c "wc -c < $_REMOTE_PATH")
    rm -f "$_LOCAL_PATH"
    _CP_CMD="kubectl cp --retries=$RETRIES $_NAMESPACE/$_POD_NAME:$_REMOTE_PATH $_LOCAL_PATH"
    if [ -n "$_CONTAINER" ]; then
        _CP_CMD="$_CP_CMD -c $_CONTAINER"
    fi
    $_CP_CMD >/dev/null 2>&1 &
    _START_TIME=$(date +%s)
    _LAST_SIZE=0
    while [ ! -f "$_LOCAL_PATH" ] || [ "$(wc -c < $_LOCAL_PATH)" -lt "$SIZE" ]; do
        [ -f "$_LOCAL_PATH" ] && _CURRENT_SIZE=$(wc -c < "$_LOCAL_PATH") || _CURRENT_SIZE=0
        _ELAPSED=$(($(date +%s) - _START_TIME))
        [ $_ELAPSED -eq 0 ] && _RATE=0 || _RATE=$((_CURRENT_SIZE / _ELAPSED))
        _PERCENT=$((_CURRENT_SIZE * 100 / SIZE))
        show_progress "$_DISPLAY_NAME" $_CURRENT_SIZE $SIZE $_RATE $_PERCENT
        _LAST_SIZE=$_CURRENT_SIZE
        sleep 1
    done
    wait
    if [ ! -f "$_LOCAL_PATH" ] || [ "$(wc -c < $_LOCAL_PATH)" -ne "$SIZE" ]; then
        rm -f "$_LOCAL_PATH"
        fail "failed to download backup for $_DISPLAY_NAME"
    fi
    printf "\033[2K\r%s %s %s\n" "$_DISPLAY_NAME" "████████████████████" "$(format_size $SIZE)" >&2
}

backup_create_temp() {
    _POD_NAME="$1"
    _NAMESPACE="$2"
    _CONTAINER="$3"
    _TEMP_PATH="$4"
    _CMD="kubectl exec $_POD_NAME -n $_NAMESPACE"
    if [ -n "$_CONTAINER" ]; then
        _CMD="$_CMD -c $_CONTAINER"
    fi
    $_CMD -- sh -c "rm -rf $_TEMP_PATH* || true"
    $_CMD -- sh -c "mkdir -p $_TEMP_PATH"
}

backup_cleanup_temp() {
    _POD_NAME="$1"
    _NAMESPACE="$2"
    _CONTAINER="$3"
    _TEMP_PATH="$4"
    _CMD="kubectl exec $_POD_NAME -n $_NAMESPACE"
    if [ -n "$_CONTAINER" ]; then
        _CMD="$_CMD -c $_CONTAINER"
    fi
    $_CMD -- sh -c "rm -rf $_TEMP_PATH*"
}

backup_compress_temp() {
    _POD_NAME="$1"
    _NAMESPACE="$2"
    _CONTAINER="$3"
    _TEMP_PATH="$4"
    _ARCHIVE_NAME="$5"
    _CMD="kubectl exec $_POD_NAME -n $_NAMESPACE"
    if [ -n "$_CONTAINER" ]; then
        _CMD="$_CMD -c $_CONTAINER"
    fi
    log "compressing $_NAMESPACE/$_POD_NAME"
    try "$_CMD -- sh -c \"cd $_TEMP_PATH && tar cf ${_TEMP_PATH}.tar.gz --use-compress-program='gzip -9' $_ARCHIVE_NAME\""
}

backup_extract_archive() {
    _ARCHIVE="$1"
    _TARGET_DIR="$2"
    mkdir -p "$_TARGET_DIR"
    cd "$_TARGET_DIR"
    tar xzf "$_ARCHIVE"
    rm -f "$_ARCHIVE"
}

wait_for_pod() {
    _NAMESPACE="$1"
    _SELECTOR="$2"
    _CONTAINER="$3"
    _I=0
    while [ $_I -lt $RETRIES ]; do
        _I="$((_I + 1))"
        if [ $_I -gt 1 ]; then
            warn "waiting for $_NAMESPACE/$(echo $_SELECTOR | cut -d= -f2) to be ready $_I/$RETRIES" >&2
            sleep 1
        fi
        _POD_NAME="$(kubectl get pods -l "$_SELECTOR" -n "$_NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
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
}
