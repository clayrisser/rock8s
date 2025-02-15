#!/bin/sh

set -e

K9S_VERSION=0.32.5
KUBECTL_VERSION=1.31.0
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
    curl \
    jc \
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
if ! which kubectl >/dev/null 2>&1; then
    _TMP_DIR=$(mktemp -d)
    (
        cd "$_TMP_DIR"
        curl -Lo kubectl \
            "https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl"
        sudo mv kubectl /usr/local/bin/kubectl
        sudo chmod +x /usr/local/bin/kubectl
    )
    rm -rf "$_TMP_DIR"
fi
if ! which k9s >/dev/null 2>&1; then
    _TMP_DIR=$(mktemp -d)
    (
        cd "$_TMP_DIR"
        curl -Lo k9s.deb \
            "https://github.com/derailed/k9s/releases/download/v$K9S_VERSION/k9s_linux_amd64.deb"
        sudo dpkg -i k9s.deb
    )
    rm -rf "$_TMP_DIR"
fi
if [ ! -f "$APPS_DIR/$APP/env/bin/pip3" ]; then
    python3 -m venv "$APPS_DIR/$APP/env"
fi
"$APPS_DIR/$APP/env/bin/pip3" install -r "$APPS_DIR/$APP/kubespray/requirements.txt"
