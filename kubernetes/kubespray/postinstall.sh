#!/bin/sh

sudo apt update
sudo apt install -y \
    open-iscsi
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/resize.sh 2>/dev/null | sh
