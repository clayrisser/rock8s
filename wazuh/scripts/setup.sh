#!/bin/sh

set -e
set -x

curl -sO https://packages.wazuh.com/4.8/wazuh-install.sh && sudo bash ./wazuh-install.sh -v -a -i
