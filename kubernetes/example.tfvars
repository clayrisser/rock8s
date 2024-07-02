env_name                 = "demo"
iteration                = "0"
cluster_domain           = "local"
pm_api_url               = "https://localhost:8006/api"
pm_api_token_id          = ""
pm_api_token_secret      = ""
pm_tls_insecure          = true
pm_host                  = "pve1"
pm_parallel              = 1
pm_timeout               = 600
internal_net_name        = "vmbr3"
internal_net_subnet_cidr = "10.0.1.0/24"
ssh_public_keys_b64      = ""
ssh_private_key_b64      = ""
vm_os_disk_storage       = "local-zfs"
vm_clone                 = "template-debian-12"

# Bastion host details. This is required for the Terraform client to 
# connect to the Kubespray VM that will be placed into the internet network
bastion_ssh_ip   = "192.168.1.131"
bastion_ssh_user = "ubuntu"
bastion_ssh_port = 22

# VM specifications
########################################################################
# Maximum cores that your Proxmox VE server can give to a VM
vm_max_vcpus = 2
# Control plane VM specifications
vm_k8s_control_plane = {
  node_count = 1
  vcpus      = 2
  memory     = 2048
  disk_size  = 20
}
# Worker nodes VM specifications
vm_k8s_worker = {
  node_count = 3
  vcpus      = 2
  memory     = 3072
  disk_size  = 20
}

# Kubernetes settings
########################################################################
kube_version               = "v1.24.6"
kube_network_plugin        = "calico"
enable_nodelocaldns        = false
podsecuritypolicy_enabled  = false
persistent_volumes_enabled = false
helm_enabled               = false
ingress_nginx_enabled      = false
argocd_enabled             = false
argocd_version             = "v2.4.12"
