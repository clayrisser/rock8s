#!/bin/sh

sudo true
export DEBIAN_FRONTEND=noninteractive
sudo apt install -y \
    git \
    git-lfs \
    jq \
    make
git lfs install
if [ ! -d yaps ]; then
    git clone https://gitlab.com/bitspur/rock8s/yaps.git
fi
set -- $(sudo pveum user token add root@pam "$(tr -dc 'a-z' < /dev/urandom | head -c 8)" --privsep 0 -o json | \
    jq -r '([.["full-tokenid"],.value]) | @tsv')
PROXMOX_TOKEN_ID="$1"
PROXMOX_TOKEN_SECRET="$2"
cd $HOME/yaps
make apply
sudo pveum user token remove "$(echo $PROXMOX_TOKEN_ID | cut -d'!' -f1)" "$(echo $PROXMOX_TOKEN_ID | cut -d'!' -f2)"
