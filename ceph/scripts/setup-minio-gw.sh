#!/bin/sh

set -e
set -x

sleep 10
export DEBIAN_FRONTEND=noninteractive
while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
   sleep 5
done
sudo apt-get update
sudo apt-get install -y \
    docker-compose
sudo /sbin/usermod -aG docker admin
cd stacks/minio-gw
env
docker-compose up -d
