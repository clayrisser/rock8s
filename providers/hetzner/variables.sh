#!/bin/sh

set -e

export TF_VAR_hetzner_token="$(get_config '.providers.hetzner.token // ""' "$HETZNER_TOKEN")"
if [ -z "$TF_VAR_hetzner_token" ]; then
    echo "missing HETZNER_TOKEN" >&2
    exit 1
fi

if [ "$TF_VAR_purpose" != "pfsense" ]; then
    _CONFIG_JSON="$(get_config_json)"
    _GATEWAY="$(calculate_first_ipv4 "$(echo "$_CONFIG_JSON" | jq -r '.network.lan.ipv4.subnet')")"
    _SSH_PUBLIC_KEY="$(cat "$TF_VAR_ssh_public_key_path")"
    export TF_VAR_user_data="#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - $_SSH_PUBLIC_KEY
write_files:
  - content: |
      vm.nr_hugepages = 1024
    path: /etc/sysctl.d/60-hugepages.conf
    owner: root:root
    permissions: '0644'
env:
  PATH: /usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/games:/usr/games
bootcmd:
  - modprobe dm_thin_pool
  - modprobe dm_snapshot
  - modprobe dm_mirror
  - modprobe dm_crypt
  - IFACE=\$(echo \$(ip link show | grep -E \"^[0-9]\" | head -n2 | tail -n1 | cut -d':' -f2))
  - echo \"auto \$IFACE\" > /etc/network/interfaces.d/50-cloud-init.cfg
  - echo \"iface \$IFACE inet dhcp\" >> /etc/network/interfaces.d/50-cloud-init.cfg
  - echo \"  up route add default gw $_GATEWAY\" >> /etc/network/interfaces.d/50-cloud-init.cfg
  - echo \"  dns-nameservers 185.12.64.2 185.12.64.1\" >> /etc/network/interfaces.d/50-cloud-init.cfg
  - systemctl restart networking
runcmd:
  - sysctl -p /etc/sysctl.d/60-hugepages.conf
  - systemctl enable iscsid
  - systemctl start iscsid
  - sudo apt-get update
package_update: true
package_upgrade: true
packages:
  - nfs-common
  - open-iscsi
  - util-linux
  - xfsprogs
"
fi
