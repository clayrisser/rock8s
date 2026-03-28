module "longhorn" {
  source        = "./modules/longhorn"
  enabled       = var.longhorn != null
  s3_endpoint   = (try(var.longhorn.s3_endpoint, "") != "" && try(var.longhorn.s3_endpoint, "") != null) ? try(var.longhorn.s3_endpoint, "") : try(var.s3.endpoint, "")
  s3_access_key = (try(var.longhorn.s3_access_key, "") != "" && try(var.longhorn.s3_access_key, "") != null) ? try(var.longhorn.s3_access_key, "") : try(var.s3.access_key, "")
  s3_secret_key = (try(var.longhorn.s3_secret_key, "") != "" && try(var.longhorn.s3_secret_key, "") != null) ? try(var.longhorn.s3_secret_key, "") : try(var.s3.secret_key, "")
  s3_bucket     = (try(var.longhorn.s3_bucket, "") != "" && try(var.longhorn.s3_bucket, "") != null) ? try(var.longhorn.s3_bucket, "") : try(var.s3.bucket, "")
  depends_on = [
    module.rancher
  ]
}
