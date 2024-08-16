#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
    python3-venv
mkdir -p "$APP_DIR"
chmod 700 "$APP_DIR"
if [ ! -d "$APP_DIR/kubespray" ]; then
    _TMP_DIR=$(mktemp -d)
    (
        cd "$_TMP_DIR"
        curl -Lo kubespray.tar.gz \
            "https://github.com/kubernetes-sigs/kubespray/archive/refs/tags/v$KUBESPRAY_VERSION.tar.gz"
        tar -xzvf kubespray.tar.gz
        mv "kubespray-$KUBESPRAY_VERSION" "$APP_DIR/kubespray"
    )
    rm -rf "$_TMP_DIR"
fi
sed -i 's|^minimal_master_memory_mb:.*|minimal_master_memory_mb: 0|g' "$APP_DIR/kubespray/roles/kubernetes/preinstall/defaults/main.yml"
sed -i 's|^minimal_node_memory_mb:.*|minimal_node_memory_mb: 0|g' "$APP_DIR/kubespray/roles/kubernetes/preinstall/defaults/main.yml"
if [ ! -f "$APP_DIR/env/bin/pip3" ]; then
    python3 -m venv "$APP_DIR/env"
fi
"$APP_DIR/env/bin/pip3" install -r "$APP_DIR/kubespray/requirements.txt"
