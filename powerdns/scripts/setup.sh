#!/bin/sh

set -e
set -x

NODE_INDEX="$${NODE_INDEX:-0}"
NAMESERVERS="${nameservers}"
PRIMARY_IP="${primary_ip}"
SECONDARY_IPS="${secondary_ips}"

sudo apt-get update
sudo apt-get install -y \
	jq \
	pdns-backend-bind \
	pdns-backend-sqlite3 \
	pdns-server \
	sqlite3
if sudo test -f /var/lib/powerdns/secret; then
    export POWERDNS_SECRET=$(sudo cat /var/lib/powerdns/secret)
else
    export POWERDNS_SECRET=$(openssl rand -base64 16 | sed 's|[+/=]||g')
    echo "$POWERDNS_SECRET" | sudo tee /var/lib/powerdns/secret >/dev/null
fi
sudo chmod 600 /var/lib/powerdns/secret
cat <<EOF | sudo tee /etc/powerdns/pdns.d/gsqlite3.conf >/dev/null
launch+=gsqlite3
gsqlite3-database=/var/lib/powerdns/pdns.sqlite3
api=yes
webserver-address=0.0.0.0
webserver-allow-from=0.0.0.0/0,::/0
api-key=$POWERDNS_SECRET
default-soa-content=$(echo "$NAMESERVERS" | cut -d',' -f$((NODE_INDEX + 1))) hostmaster.@ 0 10800 3600 604800 3600
EOF
if [ "$NODE_INDEX" = "0" ]; then
	cat <<EOF | sudo tee -a /etc/powerdns/pdns.d/gsqlite3.conf >/dev/null
master=yes
slave=no
EOF
if [ "$SECONDARY_IPS" != "" ]; then
	cat <<EOF | sudo tee -a /etc/powerdns/pdns.d/gsqlite3.conf >/dev/null
also-notify=$SECONDARY_IPS
allow-axfr-ips=$SECONDARY_IPS
EOF
fi
else
	cat <<EOF | sudo tee -a /etc/powerdns/pdns.d/gsqlite3.conf >/dev/null
master=no
slave=yes
slave-cycle-interval=60
allow-notify-from=$PRIMARY_IP
EOF
fi
if [ ! -f /var/lib/powerdns/pdns.sqlite3 ]; then
    sudo sqlite3 /var/lib/powerdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite3/schema.sqlite3.sql
fi
sudo chown pdns:pdns -R /var/lib/powerdns
sudo systemctl enable pdns
sudo systemctl restart pdns
sudo systemctl status pdns --no-pager
curl -H "X-API-Key: $POWERDNS_SECRET" http://127.0.0.1:8081/api/v1/servers/localhost/zones | jq .
(
	cd /home/admin/stacks/powerdnsadmin
	sudo -E docker compose up -d
)
echo
echo "\033[1;34mPowerDNS Admin URL:\033[0m http://localhost:9191"
echo "\033[1;34mPowerDNS API URL:\033[0m http://localhost:8081"
echo "\033[1;34mPowerDNS API Key:\033[0m $POWERDNS_SECRET"
echo "\033[1;34mPowerDNS Version:\033[0m $(sudo pdnsutil --version | cut -d' ' -f2)"
