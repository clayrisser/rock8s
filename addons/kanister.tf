module "kanister" {
  source  = "./modules/kanister"
  enabled = var.kanister != null
}
