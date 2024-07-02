variable "cluster_prefix" {
  default = "test"
}

variable "iteration" {
  default = "0"
}

variable "cluster_domain" {
  default = "local"
}

variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}

variable "pm_tls_insecure" {
  type = bool
}

variable "pm_host" {
  type = string
}

variable "pm_parallel" {
  default = 2
}

variable "pm_timeout" {
  default = 600
}

variable "internal_net_name" {
  default = "vmbr3"
}

variable "internal_net_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "ssh_private_key_b64" {
  type = string
}

variable "ssh_public_keys_b64" {
  type = string
}

variable "vm_user" {
  default = "admin"
}

variable "vm_sockets" {
  default = 1
}

variable "vm_max_vcpus" {
  default = 2
}

variable "vm_cpu_type" {
  default = "host"
}

variable "vm_os_disk_storage" {
  default = "local-zfs"
}

# variable "worker_node_data_disk_storage" {
#   type        = string
#   description = "The storage pool where the data disk is placed"
#   default     = ""
# }

# variable "worker_node_data_disk_size" {
#   type        = string
#   description = "The size of worker node data disk in Gigabyte"
#   default     = 10
# }

variable "vm_clone" {
  default = "template-debian-12"
}

# variable "bastion_ssh_ip" {
#   type        = string
#   description = "IP of the bastion host, could be either public IP or local network IP of the bastion host"
#   default     = ""
# }

# variable "bastion_ssh_user" {
#   type        = string
#   description = "The user to authenticate to the bastion host"
#   default     = "ubuntu"
# }

# variable "bastion_ssh_port" {
#   type        = number
#   description = "The SSH port number on the bastion host"
#   default     = 22
# }

# # Kuberentes VM specifications for Kubernetes nodes
# ########################################################################
# variable "vm_k8s_control_plane" {
#   type        = object({ node_count = number, vcpus = number, memory = number, disk_size = number })
#   description = "Control Plane VM specification"
#   default     = { node_count = 1, vcpus = 2, memory = 1536, disk_size = 20 }
# }

# variable "vm_k8s_worker" {
#   type        = object({ node_count = number, vcpus = number, memory = number, disk_size = number })
#   description = "Worker VM specification"
#   default     = { node_count = 2, vcpus = 2, memory = 2048, disk_size = 20 }
# }

variable "create_kubespray_host" {
  default = true
}

variable "kubespray_docker_image" {
  default = "khanhphhub/kubespray:v2.22.0"
}

# variable "kube_version" {
#   type        = string
#   description = "Kubernetes version"
#   default     = "v1.24.6"
# }
# variable "kube_network_plugin" {
#   type        = string
#   description = "The network plugin to be installed on your cluster. Example: `cilium`, `calico`, `kube-ovn`, `weave` or `flannel`"
#   default     = "calico"
# }

# variable "enable_nodelocaldns" {
#   type        = bool
#   description = "Whether to enable nodelocal dns cache on your cluster"
#   default     = false
# }
# variable "podsecuritypolicy_enabled" {
#   type        = bool
#   description = "Whether to enable pod security policy on your cluster (RBAC must be enabled either by having 'RBAC' in authorization_modes or kubeadm enabled)"
#   default     = false
# }
# variable "persistent_volumes_enabled" {
#   type        = bool
#   description = "Whether to add Persistent Volumes Storage Class for corresponding cloud provider (supported: in-tree OpenStack, Cinder CSI, AWS EBS CSI, Azure Disk CSI, GCP Persistent Disk CSI)"
#   default     = false
# }
# variable "helm_enabled" {
#   type        = bool
#   description = "Whether to enable Helm on your cluster"
#   default     = false
# }
# variable "ingress_nginx_enabled" {
#   type        = bool
#   description = "Whether to enable Nginx ingress on your cluster"
#   default     = false
# }
# variable "argocd_enabled" {
#   type        = bool
#   description = "Whether to enable ArgoCD on your cluster"
#   default     = false
# }
# variable "argocd_version" {
#   type        = string
#   description = "The ArgoCD version to be installed"
#   default     = "v2.4.12"
# }
