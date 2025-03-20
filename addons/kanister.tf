module "kanister" {
  source     = "./modules/kanister"
  enabled    = local.kanister
  access_key = try(var.s3.access_key, "")
  bucket     = try(var.kanister.bucket, "")
  endpoint   = try(var.s3.endpoint, "")
  region     = "us-east-1"
  secret_key = try(var.s3.secret_key, "")
  depends_on = [
    module.kyverno,
    module.olm
  ]
}
