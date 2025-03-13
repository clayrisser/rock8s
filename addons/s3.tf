module "s3" {
  source  = "./modules/s3"
  enabled = local.s3
  values  = <<EOF
endpoint: ${var.s3_endpoint}
accessKey: ${var.s3_access_key}
secretKey: ${var.s3_secret_key}
EOF
}
