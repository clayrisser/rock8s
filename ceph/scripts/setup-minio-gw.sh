#!/bin/sh

set -e
set -x

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y \
    docker-compose
sudo /sbin/usermod -aG docker admin
cd stacks/minio-gw
docker-compose up -d
