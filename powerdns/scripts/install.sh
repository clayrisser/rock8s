#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
alias tmpl="sh ../scripts/tmpl.sh"

if ! [ -d "/mnt/pve/cephfs" ]; then
    echo "cephfs filesystem is required" 1>&2
    exit 1
fi
if sudo test -f /mnt/pve/cephfs/shared/powerdns/secret; then
    export SECRET=$(sudo cat /mnt/pve/cephfs/shared/powerdns/secret)
else
    export SECRET=$(openssl rand -base64 16 | sed 's|[+/=]||g')
    echo "$SECRET" | sudo tee /mnt/pve/cephfs/shared/powerdns/secret >/dev/null
fi
sudo apt-get update
sudo apt-get install -y \
	pdns-backend-bind \
	pdns-backend-sqlite3 \
	pdns-server
tmpl gsqlite3.conf.tmpl | sudo tee /etc/powerdns/pdns.d/gsqlite3.conf >/dev/null
mkdir -p /mnt/pve/cephfs/shared/powerdns
sudo chmod 600 /mnt/pve/cephfs/shared/powerdns/secret
if [ ! -f /mnt/pve/cephfs/shared/powerdns/pdns.sqlite3 ]; then
    sudo sqlite3 /mnt/pve/cephfs/shared/powerdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite3/schema.sqlite3.sql
    sudo chown -R pdns:pdns /mnt/pve/cephfs/shared/powerdns
fi
sudo systemctl enable pdns
sudo systemctl restart pdns
sudo systemctl status pdns --no-pager
curl -H "X-API-Key: $SECRET" http://127.0.0.1:8081/api/v1/servers/localhost/zones | jq .
sudo mkdir -p /mnt/pve/cephfs/shared/powerdns/data
sudo touch /mnt/pve/cephfs/shared/powerdns/data/powerdns-admin.db
sudo chown -R 100:101 /mnt/pve/cephfs/shared/powerdns/data
sudo podman run -d \
	--net host \
	-e BIND_ADDRESS="0.0.0.0:9191" \
	-e PORT=9191 \
	-e SECRET_KEY="$SECRET" \
	-v /mnt/pve/cephfs/shared/powerdns/data:/data \
	docker.io/powerdnsadmin/pda-legacy:latest
