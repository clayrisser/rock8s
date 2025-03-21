#!/bin/sh

set -e

export TF_VAR_hetzner_token="$(get_config '.providers.hetzner.token // ""' "$HETZNER_TOKEN")"
if [ -z "$TF_VAR_hetzner_token" ]; then
    echo "missing HETZNER_TOKEN" >&2
    exit 1
fi

if [ "$TF_VAR_purpose" != "pfsense" ]; then
    _CONFIG_JSON="$(get_config_json)"
    _IPV4_GATEWAY="$(get_pfsense_primary_lan_ipv4)"
    _IPV4_NAT="$(get_lan_ipv4_nat)"
    _SSH_PUBLIC_KEY="$(cat "$TF_VAR_ssh_public_key_path")"
    export TF_VAR_user_data="#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - $_SSH_PUBLIC_KEY
env:
  PATH: /usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/games:/usr/games
bootcmd:
  - modprobe dm_thin_pool
  - modprobe dm_snapshot
  - modprobe dm_mirror
  - modprobe dm_crypt$([ "$_IPV4_NAT" = "1" ] && echo "
  - systemctl restart networking
  - |
    IFACE=\"\"
    while [ -z \"\$IFACE\" ]; do
      IFACE=\$(ip link show | grep -E \"^[0-9]\" | grep -vE \"eth0|lo\" | head -n1 | cut -d':' -f2 | tr -d ' ')
      if [ -z \"\$IFACE\" ]; then
        sleep 10
        systemctl restart networking
      fi
    done
    echo \"auto \$IFACE\" > /etc/network/interfaces.d/60-lan
    echo \"iface \$IFACE inet dhcp\" >> /etc/network/interfaces.d/60-lan
    echo \"  mtu 1450\" >> /etc/network/interfaces.d/60-lan
    echo \"  up route add default gw $_IPV4_GATEWAY\" >> /etc/network/interfaces.d/60-lan
    echo \"  dns-nameservers 185.12.64.2 185.12.64.1\" >> /etc/network/interfaces.d/60-lan")
  - systemctl restart networking
runcmd:
  - systemctl enable iscsid
  - systemctl start iscsid
  - apt-get update
package_update: true
package_upgrade: true
packages:
  - nfs-common
  - open-iscsi
  - util-linux
  - xfsprogs
"
fi
