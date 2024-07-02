locals {
  cluster_name = "${var.cluster_prefix}-k8s-${var.iteration}"
  cluster_fqdn = "${local.cluster_name}.${var.cluster_domain}"
}
