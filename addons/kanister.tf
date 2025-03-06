module "kanister" {
  source     = "./modules/kanister"
  enabled    = local.kanister
  access_key = var.s3_access_key
  bucket     = var.kanister_bucket
  endpoint   = var.s3_endpoint
  region     = "us-east-1"
  secret_key = var.s3_secret_key
  depends_on = [
    module.kyverno,
    module.olm
  ]
}
