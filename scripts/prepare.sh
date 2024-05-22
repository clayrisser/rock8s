#!/bin/sh

PROVIDER_VLAN_ID=4000
CONTROLLER_VLAN_ID=4001
INTERNAL_IP="10.0.0.2"
VLAN_MTU=1400

sudo true
if (! which jq >/dev/null 2>&1) || (! which git >/dev/null 2>&1) || (! which vim >/dev/null 2>&1); then
    sudo apt update
    sudo apt install -y \
        git \
        jq \
        vim
fi
NETCFG_PATH="/etc/netplan/$(sudo ls /etc/netplan | head -n 1 2>/dev/null)"
if ! which yq >/dev/null 2>&1; then
  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
  sudo chmod +x /usr/local/bin/yq
fi
if [ "$NETCFG_PATH" = "/etc/netplan/" ]; then
    echo "netplan required" 1>&2
    exit 1
fi
NIC="$(sudo cat "$NETCFG_PATH" | yq -r '(.network.ethernets | keys)[0]' 2>/dev/null)"
if [ "$NIC" = "" ]; then
    echo "no nic found" 1>&2
    exit 1
fi
cat <<EOF > netcfg-1.yaml
network:
  vlans:
    $NIC.$PROVIDER_VLAN_ID:
      id: $PROVIDER_VLAN_ID
      link: $NIC
      dhcp4: no
      mtu: $VLAN_MTU
      addresses: []
    $NIC.$CONTROLLER_VLAN_ID:
      id: $CONTROLLER_VLAN_ID
      link: $NIC
      dhcp4: no
      mtu: $VLAN_MTU
      addresses:
        - $INTERNAL_IP/24
EOF
sudo cat "$NETCFG_PATH" | yq -o=json | \
  jq "{\"network\": {\"vlans\": {\"$NIC.$PROVIDER_VLAN_ID\": {\"nameservers\": .network.ethernets.$NIC.nameservers}}}}" | \
  yq -P > netcfg-2.yaml
sudo cat "$NETCFG_PATH" | yq -o=json | \
  jq "{\"network\": {\"vlans\": {\"$NIC.$CONTROLLER_VLAN_ID\": {\"nameservers\": .network.ethernets.$NIC.nameservers}}}}" | \
  yq -P > netcfg-3.yaml
sudo cat "$NETCFG_PATH" | yq eval-all \
  'select(fileIndex == 0) * select(fileIndex == 1) * select(fileIndex == 2) * select(fileIndex == 3)' \
  - netcfg-1.yaml netcfg-2.yaml netcfg-3.yaml > netcfg.yaml
cat netcfg.yaml | sudo tee "$NETCFG_PATH"
rm netcfg-1.yaml netcfg-2.yaml netcfg-3.yaml netcfg.yaml
sudo netplan apply
