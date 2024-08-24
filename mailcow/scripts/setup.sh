#!/bin/sh

set -e
set -x

sleep 10
export DEBIAN_FRONTEND=noninteractive
if [ ! -d stacks/mailcow ]; then
    git clone https://github.com/mailcow/mailcow-dockerized stacks/mailcow
fi
cd stacks/mailcow
if [ ! -f mailcow.conf ]; then
    echo ------------
    pwd
    ls
    (echo "$MAIL_HOSTNAME"; echo UTC; echo Y; echo 1) | ./generate_config.sh
fi
# sudo -E docker compose up -d
