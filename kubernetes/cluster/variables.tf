variable "public_api_ports" {
  default = "22,443"
}

variable "public_nodes_ports" {
  default = "22,80,443,30000-32768"
}

variable "region" {
  default = "us-east-2"
}

variable "cluster_prefix" {
  default = "kops"
}

variable "iteration" {
  default = 0
}

variable "gitlab_hostname" {
  default = "gitlab.com"
}

variable "rancher_admin_password" {
  default = "rancherP@ssw0rd"
}

variable "kanister_bucket" {
  default = ""
}

variable "api_strategy" {
  default = "LB"
  validation {
    condition     = contains(["DNS", "LB"], var.api_strategy)
    error_message = "Allowed values for entrypoint_strategy are \"DNS\" or \"LB\"."
  }
}

# variable "dns_zone" {
#   type = string
# }

variable "rancher" {
  default = false
}

variable "cluster_issuer" {
  default = false
}

variable "external_dns" {
  default = false
}

variable "flux" {
  default = false
}

variable "kanister" {
  default = false
}

variable "rancher_logging" {
  default = false
}

variable "kubeconfig" {
  default = "~/.kube/config"
}

variable "ingress_nginx" {
  default = true
}

variable "olm" {
  default = false
}

variable "rancher_istio" {
  default = false
}

variable "rancher_monitoring" {
  default = false
}

variable "longhorn" {
  default = false
}

variable "autoscaler" {
  default = false
}

variable "reloader" {
  default = false
}

variable "argocd" {
  default = false
}

variable "karpenter" {
  default = false
}

variable "kyverno" {
  default = true
}

variable "crossplane" {
  default = false
}

variable "tempo" {
  default = false
}

variable "integration_operator" {
  default = false
}

variable "retention_hours" {
  default = 168
}

variable "ingress_ports" {
  default = "80,443"
}

# variable "gitlab_username" {
#   type = string
# }

# variable "gitlab_token" {
#   type = string
# }

# variable "gitlab_project_id" {
#   type = string
# }

variable "email" {
  type = string
}

variable "rancher_token" {
  type = string
}

variable "rancher_hostname" {
  default = ""
}

variable "ceph" {
  default = true
}

variable "ceph_monitors" {
  default = ""
}

variable "ceph_admin_id" {
  default = ""
}

variable "ceph_admin_key" {
  default = ""
}

variable "ceph_cluster_id" {
  default = ""
}
