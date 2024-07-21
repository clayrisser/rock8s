locals {
  net_subnet_mask = "/${split("/", var.net_subnet_cidr)[1]}"
  net_default_gw  = cidrhost(var.net_subnet_cidr, 1)
}
