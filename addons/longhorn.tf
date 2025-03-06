module "longhorn" {
  source  = "./modules/longhorn"
  enabled = var.longhorn
  depends_on = [
    module.rancher
  ]
}
