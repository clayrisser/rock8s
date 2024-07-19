#!/bin/sh

HOSTNAME="$(hostname)"
export DEBIAN_FRONTEND=noninteractive
_NODES=$(sudo pvesh get /nodes --output-format json | jq -r '.[].node' | sort)
for _NODE in $_NODES; do
    _NODE_ID=$(sudo corosync-cmapctl | grep -oP "(?<=nodelist.node.)\d+(?=.name \(str\) = $_NODE)")
    _NODE_IP=$(sudo corosync-cmapctl | grep "nodelist.node.$_NODE_ID.ring0_addr" | awk -F' = ' '{print $2}')
    if [ "$_NODE_IP" != "" ]; then
        if grep -q "$_NODE_IP" /etc/hosts; then
            sudo apt update
            sudo apt install -y radosgw ceph-mgr-dashboard
        else
            ssh admin@$_NODE_IP "
                export DEBIAN_FRONTEND=noninteractive && sudo apt-get update && \
                sudo apt-get install -y radosgw ceph-mgr-dashboard"
        fi
    fi
done
sleep 30
sudo ceph mgr module enable dashboard
printf "Enter password for cephdash: "
read -s _PASSWORD
echo
echo "$_PASSWORD" | sudo ceph dashboard ac-user-create cephdash -i - administrator
sudo ceph config-key set mgr/dashboard/server_addr ::
sudo openssl req -newkey rsa:2048 -nodes -x509 -keyout /root/dashboard-key.pem -out /root/dashboard-crt.pem -sha512 -days 3650 -subj "/CN=IT/O=ceph-mgr-dashboard" -utf8
sudo ceph config-key set mgr/dashboard/key -i /root/dashboard-key.pem
sudo ceph config-key set mgr/dashboard/crt -i /root/dashboard-crt.pem
sudo ceph mgr module disable dashboard
sudo ceph mgr module enable dashboard
sudo systemctl restart ceph-mgr@$HOSTNAME.service
sudo systemctl enable ceph-mgr@$HOSTNAME.service
