locals {
  vm_net_subnet_mask = "/${split("/", var.vm_net_subnet_cidr)[1]}"
  vm_net_default_gw  = cidrhost(var.vm_net_subnet_cidr, 1)
}
