if [ "$SSH_PUBLIC_KEYS_B64" = "" ]; then
    SSH_PUBLIC_KEYS_B64="$(cat $HOME/.ssh/id_rsa.pub | base64 -w0)"
fi
if [ "$PROXMOX_NODES" = "" ]; then
    PROXMOX_NODES="$(sudo pvesh get /nodes --output-format json | jq -r '[.[].node] | sort | tojson')"
fi
if [ "$CEPH_MONITORS" = "" ]; then
    CEPH_MONITORS="$(sudo ceph mon dump 2>/dev/null | grep "mon\." | cut -d',' -f2 | sed 's|/0].*||g' | sed 's|^v[0-9]:||g' | jq -Rsc 'split("\n")[:-1]')"
fi
if [ "$CEPH_CLUSTER_ID" = "" ]; then
    CEPH_CLUSTER_ID="$(sudo ceph mon dump 2>/dev/null | grep "fsid" | sed -e 's/.*fsid \(.*\)/\1/')"
fi
if [ "$CEPH_ADMIN_KEY" = "" ]; then
    CEPH_ADMIN_KEY="$(sudo ceph auth get-key client.$CEPH_ADMIN_ID)"
fi
if [ "$PDNS_API_URL" = "" ]; then
    _POWERDNS_VM_INFO=$(sudo pvesh get /cluster/resources --type vm --output-format json | jq -r '.[] | select(.name == "powerdns-01") | {vmid, node}')
    _POWERDNS_VM_ID=$(echo "$_POWERDNS_VM_INFO" | jq -r '.vmid')
    _POWERDNS_VM_NODE=$(echo "$_POWERDNS_VM_INFO" | jq -r '.node')
    POWERDNS_IP=$(sudo pvesh get /nodes/$_POWERDNS_VM_NODE/qemu/$_POWERDNS_VM_ID/agent/network-get-interfaces --output-format json | jq -r '.result[] | select(.name == "eth0") | ."ip-addresses"[]? | select(.["ip-address-type"] == "ipv4") | ."ip-address"')
    PDNS_API_URL="http://$POWERDNS_IP:8081"
    if [ "$PDNS_API_KEY" = "" ]; then
        PDNS_API_KEY="$(ssh admin@$POWERDNS_IP 'sudo cat /var/lib/powerdns/secret')"
    fi
fi
if [ "$S3_ENDPOINT" != "" ]; then
    if [ "$S3_ACCESS_KEY" = "" ]; then
        S3_ACCESS_KEY="$(sudo radosgw-admin user info --uid=s3 | jq -r '.keys[0].access_key')"
    fi
    if [ "$S3_SECRET_KEY" = "" ]; then
        S3_SECRET_KEY="$(sudo radosgw-admin user info --uid=s3 | jq -r '.keys[0].secret_key')"
    fi
fi

export TF_VAR_app_dir="$APPS_DIR/$APP"
export TF_VAR_argocd="$ARGOCD"
export TF_VAR_ceph="$CEPH"
export TF_VAR_ceph_admin_id="$CEPH_ADMIN_ID"
export TF_VAR_ceph_admin_key="$CEPH_ADMIN_KEY"
export TF_VAR_ceph_cluster_id="$CEPH_CLUSTER_ID"
export TF_VAR_ceph_fs_name="$CEPH_FS_NAME"
export TF_VAR_ceph_monitors="$CEPH_MONITORS"
export TF_VAR_ceph_rbd_pool="$CEPH_RBD_POOL"
export TF_VAR_clone="$CLONE"
export TF_VAR_cluster_domain="$CLUSTER_DOMAIN"
export TF_VAR_cluster_entrypoint="$CLUSTER_ENTRYPOINT"
export TF_VAR_cluster_issuer="$CLUSTER_ISSUER"
export TF_VAR_control_plane_disk_size="$CONTROL_PLANE_DISK_SIZE"
export TF_VAR_control_plane_disk_storage="$CONTROL_PLANE_DISK_STORAGE"
export TF_VAR_control_plane_memory="$CONTROL_PLANE_MEMORY"
export TF_VAR_control_plane_node_count="$CONTROL_PLANE_NODE_COUNT"
export TF_VAR_control_plane_vcpus="$CONTROL_PLANE_VCPUS"
export TF_VAR_cpu="$CPU"
export TF_VAR_email="$EMAIL"
export TF_VAR_external_dns="$EXTERNAL_DNS"
export TF_VAR_flux="$FLUX"
export TF_VAR_gitlab_hostname="$GITLAB_HOSTNAME"
export TF_VAR_gitlab_repo="$GITLAB_REPO"
export TF_VAR_gitlab_token="$GITLAB_TOKEN"
export TF_VAR_gitlab_username="$GITLAB_USERNAME"
export TF_VAR_ingress_nginx="$INGRESS_NGINX"
export TF_VAR_ingress_ports="$INGRESS_PORTS"
export TF_VAR_integration_operator="$INTEGRATION_OPERATOR"
export TF_VAR_internal_network_bridge="$INTERNAL_NETWORK_BRIDGE"
export TF_VAR_ip_range="$IP_RANGE"
export TF_VAR_iteration="$ITERATION"
export TF_VAR_kanister="$KANISTER"
export TF_VAR_kube_network_plugin="$KUBE_NETWORK_PLUGIN"
export TF_VAR_kube_version="$KUBE_VERSION"
export TF_VAR_kyverno="$KYVERNO"
export TF_VAR_longhorn="$LONGHORN"
export TF_VAR_olm="$OLM"
export TF_VAR_pdns_api_key="$PDNS_API_KEY"
export TF_VAR_pdns_api_port="$PDNS_API_PORT"
export TF_VAR_pdns_api_url="$PDNS_API_URL"
export TF_VAR_prefix="$APP"
export TF_VAR_proxmox_host="$PROXMOX_HOST"
export TF_VAR_proxmox_nodes="$PROXMOX_NODES"
export TF_VAR_proxmox_parallel="$PROXMOX_PARALLEL"
export TF_VAR_proxmox_timeout="$PROXMOX_TIMEOUT"
export TF_VAR_proxmox_tls_insecure="$PROXMOX_TLS_INSECURE"
export TF_VAR_proxmox_token_id="$PROXMOX_TOKEN_ID"
export TF_VAR_proxmox_token_secret="$PROXMOX_TOKEN_SECRET"
export TF_VAR_rancher="$RANCHER"
export TF_VAR_rancher_hostname="$RANCHER_HOSTNAME"
export TF_VAR_rancher_istio="$RANCHER_ISTIO"
export TF_VAR_rancher_logging="$RANCHER_LOGGING"
export TF_VAR_rancher_monitoring="$RANCHER_MONITORING"
export TF_VAR_rancher_token="$RANCHER_TOKEN"
export TF_VAR_reloader="$RELOADER"
export TF_VAR_s3="$S3"
export TF_VAR_s3_access_key="$S3_ACCESS_KEY"
export TF_VAR_s3_endpoint="$S3_ENDPOINT"
export TF_VAR_s3_secret_key="$S3_SECRET_KEY"
export TF_VAR_single_control_plane="$SINGLE_CONTROL_PLANE"
export TF_VAR_sockets="$SOCKETS"
export TF_VAR_ssh_public_keys_b64="$SSH_PUBLIC_KEYS_B64"
export TF_VAR_user="$USER"
export TF_VAR_vault="$VAULT"
export TF_VAR_worker_disk_size="$WORKER_DISK_SIZE"
export TF_VAR_worker_disk_storage="$WORKER_DISK_STORAGE"
export TF_VAR_worker_memory="$WORKER_MEMORY"
export TF_VAR_worker_node_count="$WORKER_NODE_COUNT"
export TF_VAR_worker_node_data_disk_size="$WORKER_NODE_DATA_DISK_SIZE"
export TF_VAR_worker_node_data_disk_storage="$WORKER_NODE_DATA_DISK_STORAGE"
export TF_VAR_worker_vcpus="$WORKER_VCPUS"
