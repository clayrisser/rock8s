#!/bin/sh

PROVIDER_OUTPUT="$DATA_DIR/$PROVIDER/.env.output"
if [ -f "$PROVIDER_OUTPUT" ]; then
    . "$PROVIDER_OUTPUT"
fi

export TF_VAR_cluster_name="$CLUSTER_NAME"
export TF_VAR_prefix="$CLUSTER_NAME"
export TF_VAR_master_ips="$MASTER_IPS"
export TF_VAR_worker_ips="$WORKER_IPS"
export TF_VAR_ssh_private_key="$SSH_PRIVATE_KEY"
export TF_VAR_ip_range="$IP_RANGE"
export TF_VAR_cluster_entrypoint="$CLUSTER_ENTRYPOINT"
export TF_VAR_iteration="$ITERATION"
export TF_VAR_user="$USER"
export TF_VAR_kubespray_version="$KUBESPRAY_VERSION"
export TF_VAR_kube_version="$KUBE_VERSION"
export TF_VAR_kube_network_plugin="$KUBE_NETWORK_PLUGIN"
export TF_VAR_pod_network_cidr="$POD_NETWORK_CIDR"
export TF_VAR_service_network_cidr="$SERVICE_NETWORK_CIDR"
export TF_VAR_node_local_dns="$NODE_LOCAL_DNS"
export TF_VAR_single_control_plane="$SINGLE_CONTROL_PLANE"
export TF_VAR_dualstack="$DUALSTACK"
export TF_VAR_ceph_provisioner_monitors="$CEPH_MONITORS"
export TF_VAR_ceph_provisioner_admin_id="$CEPH_ADMIN_ID"
export TF_VAR_ceph_provisioner_secret="$CEPH_ADMIN_KEY"
