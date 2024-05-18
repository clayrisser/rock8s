#!/bin/sh

OPENSTACK_VERSION=2023.2

sudo true
sudo apt update
sudo apt install -y \
    git \
    snapd \
    vim
sudo snap install yq
NETCFG_PATH="/etc/netplan/$(ls /etc/netplan 2>/dev/null)"
if [ "$NETCFG_PATH" = "/etc/netplan/" ]; then
    echo "netplan required" 1>&2
    exit 1
fi
NIC="$(sudo cat "$NETCFG_PATH" | yq -r '(.network.ethernets | keys)[0]' 2>/dev/null)"
if [ "$NIC" = "" ]; then
    echo "no nic found" 1>&2
    exit 1
fi
cat <<EOF > netcfg-0.yaml
network:
  vlans:
    eno1:
      id: 10
      link: $NIC
      addresses: [172.16.1.201/24]
      nameservers:
        addresses: [185.12.64.1, 185.12.64.2]
      routes:
        - to: 0.0.0.0/0
          via: 172.16.1.1
          table: 100
      routing-policy:
        - from: 172.16.1.0/24
          table: 100
    eno2:
      id: 20
      link: $NIC
      addresses: [172.16.2.2/24]
      nameservers:
        addresses: [185.12.64.1, 185.12.64.2]
      routes:
        - to: 0.0.0.0/0
          via: 172.16.2.1
          table: 200
      routing-policy:
        - from: 172.16.2.0/24
          table: 200
EOF
sudo cat "$NETCFG_PATH" | yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' - netcfg-0.yaml > netcfg-1.yaml
cat netcfg-1.yaml | sudo tee "$NETCFG_PATH"
rm netcfg-0.yaml netcfg-1.yaml
sudo netplan apply
sudo snap install openstack --channel "$OPENSTACK_VERSION"
sunbeam prepare-node-script | bash -x
newgrp snap_daemon
printf "To observe progress, run each command in a new session:\n\n"
printf "    \e[32mwatch snap list\e[0m\n\n"
printf "    \e[32mwatch --color -- juju status --color -m openstack\e[0m\n\n"
printf "    \e[32msudo watch microk8s.kubectl get all -A\e[0m\n\n"
sunbeam cluster bootstrap --accept-defaults
