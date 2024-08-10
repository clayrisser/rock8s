if [ "$SSH_PUBLIC_KEYS_B64" = "" ]; then
    SSH_PUBLIC_KEYS_B64="$(cat $HOME/.ssh/id_rsa.pub | base64 -w0)"
fi

export TF_VAR_app_dir="$APP_DIR"
export TF_VAR_argocd_enabled="$ARGOCD_ENABLED"
export TF_VAR_argocd_version="$ARGOCD_VERSION"
export TF_VAR_clone="$CLONE"
export TF_VAR_cluster_domain="$CLUSTER_DOMAIN"
export TF_VAR_cluster_prefix="$CLUSTER_PREFIX"
export TF_VAR_cores="$CORES"
export TF_VAR_cpu="$CPU"
export TF_VAR_enable_nodelocaldns="$ENABLE_NODELOCALDNS"
export TF_VAR_helm_enabled="$HELM_ENABLED"
export TF_VAR_ingress_nginx_enabled="$INGRESS_NGINX_ENABLED"
export TF_VAR_internal_network_bridge="$INTERNAL_NETWORK_BRIDGE"
export TF_VAR_iteration="$ITERATION"
export TF_VAR_k8s_control_plane_disk_size="$K8S_CONTROL_PLANE_DISK_SIZE"
export TF_VAR_k8s_control_plane_memory="$K8S_CONTROL_PLANE_MEMORY"
export TF_VAR_k8s_control_plane_node_count="$K8S_CONTROL_PLANE_NODE_COUNT"
export TF_VAR_k8s_control_plane_vcpus="$K8S_CONTROL_PLANE_VCPUS"
export TF_VAR_k8s_worker_disk_size="$K8S_WORKER_DISK_SIZE"
export TF_VAR_k8s_worker_memory="$K8S_WORKER_MEMORY"
export TF_VAR_k8s_worker_node_count="$K8S_WORKER_NODE_COUNT"
export TF_VAR_k8s_worker_vcpus="$K8S_WORKER_VCPUS"
export TF_VAR_kube_network_plugin="$KUBE_NETWORK_PLUGIN"
export TF_VAR_kube_version="$KUBE_VERSION"
export TF_VAR_os_disk_storage="$OS_DISK_STORAGE"
export TF_VAR_persistent_volumes_enabled="$PERSISTENT_VOLUMES_ENABLED"
export TF_VAR_podsecuritypolicy_enabled="$PODSECURITYPOLICY_ENABLED"
export TF_VAR_proxmox_host="$PROXMOX_HOST"
export TF_VAR_proxmox_nodes="$(sudo pvesh get /nodes --output-format json | jq -r '[.[].node] | sort | tojson')"
export TF_VAR_proxmox_parallel="$PROXMOX_PARALLEL"
export TF_VAR_proxmox_timeout="$PROXMOX_TIMEOUT"
export TF_VAR_proxmox_tls_insecure="$PROXMOX_TLS_INSECURE"
export TF_VAR_proxmox_token_id="$PROXMOX_TOKEN_ID"
export TF_VAR_proxmox_token_secret="$PROXMOX_TOKEN_SECRET"
export TF_VAR_sockets="$SOCKETS"
export TF_VAR_ssh_public_keys_b64="$SSH_PUBLIC_KEYS_B64"
export TF_VAR_user="$USER"
export TF_VAR_worker_node_data_disk_size="$WORKER_NODE_DATA_DISK_SIZE"
export TF_VAR_worker_node_data_disk_storage="$WORKER_NODE_DATA_DISK_STORAGE"
