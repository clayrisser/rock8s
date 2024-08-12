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

variable "main_bucket" {
  default = ""
}

variable "oidc_bucket" {
  default = ""
}

variable "tempo_bucket" {
  default = ""
}

variable "thanos_bucket" {
  default = ""
}

variable "loki_bucket" {
  default = ""
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
  default = true
}

variable "cluster_issuer" {
  default = true
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

variable "thanos" {
  default = false
}

variable "tempo" {
  default = false
}

variable "longhorn" {
  default = false
}

variable "autoscaler" {
  default = true
}

variable "reloader" {
  default = true
}

variable "argocd" {
  default = false
}

variable "karpenter" {
  default = false
}

variable "kyverno" {
  default = false
}

variable "crossplane" {
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

# variable "email" {
#   type = string
# }

# variable "rancher_token" {
#   type = string
# }
