#!/bin/sh

KUBESPRAY_VERSION=2.25.0
KUBESPRAY_DATA_DIR="${kubespray_data_dir}"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
    python3-venv
mkdir -p "$KUBESPRAY_DATA_DIR"
rm -rf "$KUBESPRAY_DATA_DIR/*"
chmod 700 "$KUBESPRAY_DATA_DIR"
cd "$KUBESPRAY_DATA_DIR"
curl -Lo kubespray.tar.gz \
    "https://github.com/kubernetes-sigs/kubespray/archive/refs/tags/v${KUBESPRAY_VERSION}.tar.gz"
tar -xzvf kubespray.tar.gz
rm kubespray.tar.gz
mv "kubespray-${KUBESPRAY_VERSION}" kubespray
python3 -m venv env
env/bin/pip3 install -r kubespray/requirements.txt
