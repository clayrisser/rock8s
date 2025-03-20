module "olm" {
  source  = "./modules/olm"
  enabled = var.olm != null
}
