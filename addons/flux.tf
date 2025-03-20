module "flux" {
  source  = "./modules/flux"
  enabled = var.flux != null
}
