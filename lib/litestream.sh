#!/bin/sh

set -e

LITESTREAM_VERSION="${LITESTREAM_VERSION:-0.5.10}"

setup_litestream() {
    backend="$(get_state_backend)"
    if [ "$backend" != "s3" ]; then
        return 0
    fi

    master_count="$(get_master_node_count)"
    if [ "$master_count" -gt 1 ]; then
        log "skipping litestream (HA mode uses embedded etcd)"
        return 0
    fi

    bucket="$(get_config '.state.bucket // ""')"
    region="$(get_config '.state.region // "us-east-1"')"
    endpoint="$(get_config '.state.endpoint // ""')"
    access_key="$(get_config '.state.access_key // ""' "${AWS_ACCESS_KEY_ID:-}")"
    secret_key="$(get_config '.state.secret_key // ""' "${AWS_SECRET_ACCESS_KEY:-}")"

    if [ -z "$access_key" ] || [ -z "$secret_key" ]; then
        warn "S3 credentials not available, skipping litestream setup"
        return 0
    fi

    first_master="$(get_k3s_first_master_ip)"
    ssh_key="$(get_master_ssh_private_key)"
    ssh_user="$(get_node_ssh_user)"
    cluster="$ROCK8S_CLUSTER"

    log "configuring litestream on $first_master"

    arch="$(ssh -o StrictHostKeyChecking=no -i "$ssh_key" "$ssh_user@$first_master" "uname -m")"
    case "$arch" in
    x86_64) deb_arch="x86_64" ;;
    aarch64) deb_arch="arm64" ;;
    *)
        warn "unsupported architecture for litestream: $arch"
        return 0
        ;;
    esac

    ssh -o StrictHostKeyChecking=no -i "$ssh_key" "$ssh_user@$first_master" "
        if ! command -v litestream >/dev/null 2>&1; then
            wget -qO /tmp/litestream.deb 'https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${deb_arch}.deb'
            sudo dpkg -i /tmp/litestream.deb
            rm -f /tmp/litestream.deb
        fi
    " >&2

    endpoint_yaml=""
    if [ -n "$endpoint" ]; then
        endpoint_yaml="
        endpoint: $endpoint
        force-path-style: true"
    fi

    cat <<LITESTREAM_EOF | ssh -o StrictHostKeyChecking=no -i "$ssh_key" "$ssh_user@$first_master" \
        "sudo tee /etc/litestream.yml >/dev/null && sudo chmod 600 /etc/litestream.yml"
dbs:
  - path: /var/lib/rancher/k3s/server/db/state.db
    replicas:
      - type: s3
        bucket: $bucket
        path: ${cluster}/k3s
        region: $region
        access-key-id: $access_key
        secret-access-key: $secret_key${endpoint_yaml}
LITESTREAM_EOF

    ssh -o StrictHostKeyChecking=no -i "$ssh_key" "$ssh_user@$first_master" "
        sudo systemctl enable litestream
        sudo systemctl restart litestream
    " >&2

    log "backing up k3s token to s3://$bucket/${cluster}/k3s/token"
    ssh -o StrictHostKeyChecking=no -i "$ssh_key" "$ssh_user@$first_master" \
        "sudo cat /var/lib/rancher/k3s/server/token" |
        s3_put_stdin "$bucket" "${cluster}/k3s/token" "$region" "$endpoint" "$access_key" "$secret_key"

    log "litestream replicating to s3://$bucket/${cluster}/k3s"
}
