if [ "$SSH_PUBLIC_KEYS_B64" = "" ]; then
    SSH_PUBLIC_KEYS_B64="$(cat $HOME/.ssh/id_rsa.pub | base64 -w0)"
fi
if [ "$SSH_PRIVATE_KEY_B64" = "" ]; then
    SSH_PRIVATE_KEY_B64="$(cat $HOME/.ssh/id_rsa | base64 -w0)"
fi
if [ "$PROXMOX_NODES" = "" ]; then
    # PROXMOX_NODES="$(sudo pvesh get /nodes --output-format json | jq -r '[.[].node] | sort | tojson')"
    PROXMOX_NODES="[\"$(hostname)\"]"
fi

export TF_VAR_clone="$CLONE"
export TF_VAR_count="$COUNT"
export TF_VAR_cpu="$CPU"
export TF_VAR_disk_size="$DISK_SIZE"
export TF_VAR_mail_hostname="$MAIL_HOSTNAME"
export TF_VAR_memory="$MEMORY"
export TF_VAR_network_bridge="$NETWORK_BRIDGE"
export TF_VAR_os_disk_storage="$OS_DISK_STORAGE"
export TF_VAR_proxmox_host="$PROXMOX_HOST"
export TF_VAR_proxmox_nodes="$PROXMOX_NODES"
export TF_VAR_proxmox_parallel="$PROXMOX_PARALLEL"
export TF_VAR_proxmox_timeout="$PROXMOX_TIMEOUT"
export TF_VAR_proxmox_tls_insecure="$PROXMOX_TLS_INSECURE"
export TF_VAR_proxmox_token_id="$PROXMOX_TOKEN_ID"
export TF_VAR_proxmox_token_secret="$PROXMOX_TOKEN_SECRET"
export TF_VAR_sockets="$SOCKETS"
export TF_VAR_ssh_private_key_b64="$SSH_PRIVATE_KEY_B64"
export TF_VAR_ssh_public_keys_b64="$SSH_PUBLIC_KEYS_B64"
export TF_VAR_user="$USER"
export TF_VAR_vcpus="$VCPUS"
export TF_VAR_worker_node_data_disk_size="$WORKER_NODE_DATA_DISK_SIZE"
export TF_VAR_worker_node_data_disk_storage="$WORKER_NODE_DATA_DISK_STORAGE"
