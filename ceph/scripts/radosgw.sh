#!/bin/sh

HOSTNAME="$(hostname)"
export DEBIAN_FRONTEND=noninteractive
if ! sudo test -f /etc/ceph/ceph.client.radosgw.keyring; then
    sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.radosgw.keyring
fi
if ! sudo test -f /etc/ceph/ceph.client.admin.keyring; then
    sudo tee /etc/ceph/ceph.client.admin.keyring <<EOF
[client.admin]
    key = $(sudo ceph --cluster ceph auth get-key client.admin)
    caps mds = "allow *"
    caps mgr = "allow *"
    caps mon = "allow *"
    caps osd = "allow *"
EOF
fi
_NODES=$(sudo pvesh get /nodes --output-format json | jq -r '.[].node' | sort)
for _NODE in $_NODES; do
    sudo ceph auth del client.radosgw.$_NODE
    sudo ceph-authtool /etc/ceph/ceph.client.radosgw.keyring -n client.radosgw.$_NODE --gen-key
    sudo ceph-authtool -n client.radosgw.$_NODE --cap osd 'allow rwx' --cap mon 'allow rwx' /etc/ceph/ceph.client.radosgw.keyring
    sudo ceph -k /etc/ceph/ceph.client.admin.keyring auth add client.radosgw.$_NODE -i /etc/ceph/ceph.client.radosgw.keyring
done
_DOMAIN=$(cat /etc/hosts | grep "$HOSTNAME" | grep -oE "$HOSTNAME\.[^ ]+" | sed "s|^$HOSTNAME\.||g")
for _NODE in $_NODES; do
    _NODE_ID=$(sudo corosync-cmapctl | grep -oP "(?<=nodelist.node.)\d+(?=.name \(str\) = $_NODE)")
    _NODE_IP=$(sudo corosync-cmapctl | grep "nodelist.node.$_NODE_ID.ring0_addr" | awk -F' = ' '{print $2}')
    if ! sudo grep -q "client.radosgw.$_NODE" /etc/ceph/ceph.conf; then
        sudo tee -a /etc/ceph/ceph.conf >/dev/null <<EOF
[client.radosgw.$_NODE]
    host = $_NODE
    keyring = /etc/pve/priv/ceph.client.radosgw.keyring
    log file = /var/log/ceph/client.radosgw.$_NODE.log
    rgw_dns_name = s3.$_DOMAIN
EOF
    fi
done
sudo cp /etc/ceph/ceph.client.admin.keyring /etc/pve/priv
sudo cp /etc/ceph/ceph.client.radosgw.keyring /etc/pve/priv
for _NODE in $_NODES; do
    _NODE_ID=$(sudo corosync-cmapctl | grep -oP "(?<=nodelist.node.)\d+(?=.name \(str\) = $_NODE)")
    _NODE_IP=$(sudo corosync-cmapctl | grep "nodelist.node.$_NODE_ID.ring0_addr" | awk -F' = ' '{print $2}')
    if [ "$_NODE_IP" != "" ]; then
        if grep -q "$_NODE_IP" /etc/hosts; then
            sudo apt-get update
            sudo apt-get install -y radosgw
            sudo mkdir -p /etc/systemd/system/ceph-radosgw.target.wants
            (sudo test -f /etc/systemd/system/ceph-radosgw.target.wants/ceph-radosgw@radosgw.radosgw.$_NODE || \
                sudo ln -s /lib/systemd/system/ceph-radosgw@.service /etc/systemd/system/ceph-radosgw.target.wants/ceph-radosgw@radosgw.radosgw.$_NODE) && \
            sudo systemctl daemon-reload
            sudo systemctl start ceph-radosgw@radosgw.$_NODE
            sudo systemctl enable ceph-radosgw@radosgw.$_NODE
        else
            ssh admin@$_NODE_IP "
                sudo cp /etc/pve/priv/ceph.client.admin.keyring /etc/ceph/ceph.client.admin.keyring && \
                sudo cp /etc/pve/priv/ceph.client.radosgw.keyring /etc/ceph/ceph.client.radosgw.keyring && \
                export DEBIAN_FRONTEND=noninteractive && sudo apt-get update && \
                sudo apt-get install -y radosgw && \
                sudo mkdir -p /etc/systemd/system/ceph-radosgw.target.wants && \
                (sudo test -f /etc/systemd/system/ceph-radosgw.target.wants/ceph-radosgw@radosgw.radosgw.$_NODE || \
                    sudo ln -s /lib/systemd/system/ceph-radosgw@.service /etc/systemd/system/ceph-radosgw.target.wants/ceph-radosgw@radosgw.radosgw.$_NODE) && \
                sudo systemctl daemon-reload && \
                sudo systemctl start ceph-radosgw@radosgw.$_NODE && \
                sudo systemctl enable ceph-radosgw@radosgw.$_NODE"
        fi
    fi
done
if sudo radosgw-admin user info --uid=s3 > /dev/null 2>&1; then
    sudo radosgw-admin user info --uid=s3
else
    sudo radosgw-admin user create --uid=s3 --display-name="S3" --email="s3@$_DOMAIN"
fi
if ! which s3cmd >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y s3cmd
fi
cat > /home/admin/.s3cfg <<EOF
[default]
access_key = $(sudo radosgw-admin user info --uid=s3 | jq -r '.keys[0].access_key')
secret_key = $(sudo radosgw-admin user info --uid=s3 | jq -r '.keys[0].secret_key')
host_base = 127.0.0.1:7480
host_bucket = 127.0.0.1:7480/%(bucket)
check_ssl_certificate = True
check_ssl_hostname = True
connection_max_age = 5
connection_pooling = True
default_mime_type = binary/octet-stream
delay_updates = False
delete_after = False
delete_after_fetch = False
delete_removed = False
dry_run = False
enable_multipart = True
encoding = UTF-8
encrypt = False
follow_symlinks = False
force = False
get_continue = False
guess_mime_type = True
human_readable_sizes = False
invalidate_default_index_on_cf = False
invalidate_default_index_root_on_cf = True
invalidate_on_cf = False
limit = -1
limitrate = 0
list_allow_unordered = False
list_md5 = False
long_listing = False
max_delete = -1
multipart_chunk_size_mb = 15
multipart_copy_chunk_size_mb = 1024
multipart_max_chunks = 10000
preserve_attrs = True
progress_meter = True
proxy_port = 0
public_url_use_https = False
put_continue = False
recursive = False
recv_chunk = 65536
reduced_redundancy = False
requester_pays = False
restore_days = 1
restore_priority = Standard
send_chunk = 65536
server_side_encryption = False
signature_v2 = False
signurl_use_https = False
skip_existing = False
socket_timeout = 300
stats = False
stop_on_error = False
throttle_max = 100
urlencoding_mode = normal
use_http_expect = False
use_https = False
use_mime_magic = True
verbosity = WARNING
website_index = index.html
EOF
sudo chmod 600 /home/admin/.s3cfg
sudo ceph osd pool application enable .rgw.root rgw || true
sudo ceph osd pool application enable default.rgw.control rgw || true
sudo ceph osd pool application enable default.rgw.data.root rgw || true
sudo ceph osd pool application enable default.rgw.gc rgw || true
sudo ceph osd pool application enable default.rgw.log rgw || true
sudo ceph osd pool application enable default.rgw.users.uid rgw || true
sudo ceph osd pool application enable default.rgw.users.email rgw || true
sudo ceph osd pool application enable default.rgw.users.keys rgw || true
sudo ceph osd pool application enable default.rgw.buckets.index rgw || true
sudo ceph osd pool application enable default.rgw.buckets.data rgw || true
sudo ceph osd pool application enable default.rgw.lc rgw || true
