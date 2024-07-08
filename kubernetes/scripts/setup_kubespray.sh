#!/bin/sh

KUBESPRAY_VERSION=2.25.0
KUBESPRAY_DATA_DIR="${kubespray_data_dir}"
echo KUBESPRAY_DATA_DIR $KUBESPRAY_DATA_DIR
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
    python3-venv
mkdir -p "$KUBESPRAY_DATA_DIR"
rm -rf "$KUBESPRAY_DATA_DIR/*"
chmod 700 "$KUBESPRAY_DATA_DIR"
cd "$KUBESPRAY_DATA_DIR"
if [ -d kubespray ]; then
    curl -Lo kubespray.tar.gz \
        "https://github.com/kubernetes-sigs/kubespray/archive/refs/tags/v$KUBESPRAY_VERSION.tar.gz"
    tar -xzvf kubespray.tar.gz
    rm kubespray.tar.gz
    mv "kubespray-$KUBESPRAY_VERSION" kubespray
fi
sed -i 's|^minimal_master_memory_mb:.*|minimal_master_memory_mb: 0|g' kubespray/roles/kubernetes/preinstall/defaults/main.yml
sed -i 's|^minimal_node_memory_mb:.*|minimal_node_memory_mb: 0|g' kubespray/roles/kubernetes/preinstall/defaults/main.yml
if [ ! -f env/bin/pip3 ]; then
    python3 -m venv env
fi
env/bin/pip3 install -r kubespray/requirements.txt
