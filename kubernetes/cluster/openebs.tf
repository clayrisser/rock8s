module "openebs" {
  source  = "./modules/openebs"
  enabled = var.openebs
  depends_on = [
    module.rancher
  ]
}
