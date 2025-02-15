#!/bin/sh

set -e

PROVIDER_OUTPUT="$DATA_DIR/$PROVIDER/.env.output"
if [ -f "$PROVIDER_OUTPUT" ]; then
    . "$PROVIDER_OUTPUT"
fi
if [ ! -f "$KUBESPRAY_DIR/requirements.txt" ]; then
    curl -L "https://github.com/kubernetes-sigs/kubespray/archive/$KUBESPRAY_VERSION.tar.gz" | \
        tar -xz
    mv kubespray-$KUBESPRAY_VERSION "$KUBESPRAY_DIR"
fi
if [ ! -f "$KUBESPRAY_DIR/env/bin/pip3" ]; then
    python3 -m venv "$KUBESPRAY_DIR/env"
    "$KUBESPRAY_DIR/env/bin/pip3" install -r "$KUBESPRAY_DIR/requirements.txt"
fi
K9S_VERSION=0.32.5
KUBECTL_VERSION=1.31.0
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
    curl \
    jc \
    python3-venv
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
