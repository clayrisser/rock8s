#!/bin/sh

set -e

backup_download_with_progress() {
    pod_name="$1"
    namespace="$2"
    container="$3"
    remote_path="$4"
    local_path="$5"
    display_name="$6"
    cmd="kubectl exec $pod_name -n $namespace"
    if [ -n "$container" ]; then
        cmd="$cmd -c $container"
    fi
    SIZE=$($cmd -- sh -c "wc -c < $remote_path")
    rm -f "$local_path"
    cp_cmd="kubectl cp --retries=$RETRIES $namespace/$pod_name:$remote_path $local_path"
    if [ -n "$container" ]; then
        cp_cmd="$cp_cmd -c $container"
    fi
    $cp_cmd >/dev/null 2>&1 &
    start_time=$(date +%s)
    while [ ! -f "$local_path" ] || [ "$(wc -c <"$local_path")" -lt "$SIZE" ]; do
        [ -f "$local_path" ] && current_size=$(wc -c <"$local_path") || current_size=0
        elapsed=$(($(date +%s) - start_time))
        [ $elapsed -eq 0 ] && rate=0 || rate=$((current_size / elapsed))
        percent=$((current_size * 100 / SIZE))
        show_progress "$display_name" $current_size $SIZE $rate $percent
        sleep 1
    done
    wait
    if [ ! -f "$local_path" ] || [ "$(wc -c <"$local_path")" -ne "$SIZE" ]; then
        rm -f "$local_path"
        fail "failed to download backup for $display_name"
    fi
    printf "\033[2K\r%s %s %s\n" "$display_name" "████████████████████" "$(format_size $SIZE)" >&2
}

backup_create_temp() {
    pod_name="$1"
    namespace="$2"
    container="$3"
    temp_path="$4"
    cmd="kubectl exec $pod_name -n $namespace"
    if [ -n "$container" ]; then
        cmd="$cmd -c $container"
    fi
    $cmd -- sh -c "rm -rf $temp_path* || true"
    $cmd -- sh -c "mkdir -p $temp_path"
}

backup_cleanup_temp() {
    pod_name="$1"
    namespace="$2"
    container="$3"
    temp_path="$4"
    cmd="kubectl exec $pod_name -n $namespace"
    if [ -n "$container" ]; then
        cmd="$cmd -c $container"
    fi
    $cmd -- sh -c "rm -rf $temp_path*"
}

backup_compress_temp() {
    pod_name="$1"
    namespace="$2"
    container="$3"
    temp_path="$4"
    archive_name="$5"
    cmd="kubectl exec $pod_name -n $namespace"
    if [ -n "$container" ]; then
        cmd="$cmd -c $container"
    fi
    log "compressing $namespace/$pod_name"
    try "$cmd -- sh -c \"cd $temp_path && tar cf ${temp_path}.tar.gz --use-compress-program='gzip -9' $archive_name\""
}

backup_extract_archive() {
    archive="$1"
    target_dir="$2"
    mkdir -p "$target_dir"
    cd "$target_dir"
    tar xzf "$archive"
    rm -f "$archive"
}

wait_for_pod() {
    namespace="$1"
    selector="$2"
    container="$3"
    i=0
    while [ $i -lt $RETRIES ]; do
        i=$((i + 1))
        if [ $i -gt 1 ]; then
            warn "waiting for $namespace/$(echo $selector | cut -d= -f2) to be ready $i/$RETRIES" >&2
            sleep 1
        fi
        pod_name="$(kubectl get pods -l "$selector" -n "$namespace" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
        if [ -n "$pod_name" ]; then
            cmd="kubectl exec $pod_name -n $namespace"
            if [ -n "$container" ]; then
                cmd="$cmd -c $container"
            fi
            if $cmd -- sh -c "echo 'pod is ready'" >/dev/null 2>&1; then
                echo "$pod_name"
                return
            fi
        fi
    done
}
