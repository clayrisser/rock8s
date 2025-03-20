module "integration-operator" {
  source  = "./modules/integration_operator"
  enabled = var.integration_operator != null
}
