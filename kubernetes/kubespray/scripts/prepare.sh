#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
    python3-venv
mkdir -p "$APPS_DIR/$APP"
chmod 700 "$APPS_DIR/$APP"
if [ ! -d "$APPS_DIR/$APP/kubespray" ]; then
    _TMP_DIR=$(mktemp -d)
    (
        cd "$_TMP_DIR"
        curl -Lo kubespray.tar.gz \
            "https://github.com/kubernetes-sigs/kubespray/archive/refs/tags/v$KUBESPRAY_VERSION.tar.gz"
        tar -xzvf kubespray.tar.gz
        mv "kubespray-$KUBESPRAY_VERSION" "$APPS_DIR/$APP/kubespray"
    )
    rm -rf "$_TMP_DIR"
fi
sed -i 's|^minimal_master_memory_mb:.*|minimal_master_memory_mb: 0|g' "$APPS_DIR/$APP/kubespray/roles/kubernetes/preinstall/defaults/main.yml"
sed -i 's|^minimal_node_memory_mb:.*|minimal_node_memory_mb: 0|g' "$APPS_DIR/$APP/kubespray/roles/kubernetes/preinstall/defaults/main.yml"
if [ ! -f "$APPS_DIR/$APP/env/bin/pip3" ]; then
    python3 -m venv "$APPS_DIR/$APP/env"
fi
"$APPS_DIR/$APP/env/bin/pip3" install -r "$APPS_DIR/$APP/kubespray/requirements.txt"
