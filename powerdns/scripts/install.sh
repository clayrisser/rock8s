#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
alias tmpl="sh ../scripts/tmpl.sh"
HOST_NUMBER="$(echo "$(hostname)" | sed 's/[^0-9]//g')"
export SOA_CONTENT="ns$HOST_NUMBER.@ hostmaster.@ 0 10800 3600 604800 3600"

for n in $(sudo pvesh get /nodes --output-format json | jq -r '.[].node' | sort); do
	_IP="$(sudo grep -A 5 "name: $n" /etc/pve/corosync.conf | grep 'ring0_addr' | cut -d ':' -f 2 | tr -d ' ')"
	_HOST_NUMBER="$(echo "$n" | sed 's/[^0-9]//g')"
	if ! grep -q "ns$_HOST_NUMBER.$(hostname -d)" /etc/hosts; then
		echo "$_IP ns$_HOST_NUMBER.$(hostname -d)" | sudo tee -a /etc/hosts >/dev/null
	fi
done
if [ "$HOST_NUMBER" = "1" ]; then
	SECONDARY_IPS=""
	for n in $(sudo pvesh get /nodes --output-format json | jq -r '.[].node' | sort | grep -v $(hostname) | head -n1); do
		_SECONDARY_IPS="$(sudo grep -A 5 "name: $n" /etc/pve/corosync.conf | grep 'ring0_addr' | cut -d ':' -f 2 | tr -d ' ')"
		if [ "$SECONDARY_IPS" = "" ]; then
			SECONDARY_IPS="$_SECONDARY_IPS"
		else
			SECONDARY_IPS="$SECONDARY_IPS,$_SECONDARY_IPS"
		fi
	done
    export PRIMARY_SECONDARY="master=yes
slave=no
also-notify=$SECONDARY_IPS
allow-axfr-ips=$SECONDARY_IPS"
else
	ALLOW_NOTIFY_FROM="allow-notify-from=$(sudo grep -A 5 "name: $(sudo pvesh get /nodes --output-format json | jq -r '.[].node' | sort | head -n1)" /etc/pve/corosync.conf | grep 'ring0_addr' | cut -d ':' -f 2 | tr -d ' ')"
    export PRIMARY_SECONDARY="master=no
slave=yes
slave-cycle-interval=60
$ALLOW_NOTIFY_FROM"
fi
if sudo test -f /var/lib/powerdns/secret; then
    export SECRET=$(sudo cat /var/lib/powerdns/secret)
else
    export SECRET=$(openssl rand -base64 16 | sed 's|[+/=]||g')
    echo "$SECRET" | sudo tee /var/lib/powerdns/secret >/dev/null
fi
sudo apt-get update
sudo apt-get install -y \
	pdns-backend-bind \
	pdns-backend-sqlite3 \
	pdns-server
tmpl gsqlite3.conf.tmpl | sudo tee /etc/powerdns/pdns.d/gsqlite3.conf >/dev/null
sudo chmod 600 /var/lib/powerdns/secret
if [ ! -f /var/lib/powerdns/pdns.sqlite3 ]; then
    sudo sqlite3 /var/lib/powerdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite3/schema.sqlite3.sql
fi
sudo chown pdns:pdns -R /var/lib/powerdns
sudo systemctl enable pdns
sudo systemctl restart pdns
sudo systemctl status pdns --no-pager
curl -H "X-API-Key: $SECRET" http://127.0.0.1:8081/api/v1/servers/localhost/zones | jq .
sudo podman run -d \
	--net host \
	-e BIND_ADDRESS="0.0.0.0:9191" \
	-e PORT=9191 \
	-e SECRET_KEY="$SECRET" \
	-v pdns-data:/data \
	docker.io/powerdnsadmin/pda-legacy:latest
echo
echo "\033[1;34mPowerDNS API URL:\033[0m http://localhost:8081"
echo "\033[1;34mPowerDNS API Key:\033[0m $(sudo cat /var/lib/powerdns/secret)"
echo "\033[1;34mPowerDNS Version:\033[0m $(sudo pdnsutil --version | cut -d' ' -f2)"
