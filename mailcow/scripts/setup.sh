#!/bin/sh

set -e
set -x

sleep 10
export DEBIAN_FRONTEND=noninteractive
while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
   sleep 5
done
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y \
    containerd.io \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin
sudo /sbin/usermod -aG docker admin
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
