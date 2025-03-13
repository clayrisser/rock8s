module "longhorn" {
  source        = "./modules/longhorn"
  enabled       = var.longhorn
  s3_endpoint   = var.longhorn_s3_endpoint != "" ? var.longhorn_s3_endpoint : var.s3_endpoint
  s3_access_key = var.longhorn_s3_access_key != "" ? var.longhorn_s3_access_key : var.s3_access_key
  s3_secret_key = var.longhorn_s3_secret_key != "" ? var.longhorn_s3_secret_key : var.s3_secret_key
  s3_bucket     = var.longhorn_s3_bucket
  depends_on = [
    module.rancher
  ]
}
