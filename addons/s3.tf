module "s3" {
  source  = "./modules/s3"
  enabled = local.s3
  values  = <<EOF
endpoint: ${try(var.s3.endpoint, "")}
accessKey: ${try(var.s3.access_key, "")}
secretKey: ${try(var.s3.secret_key, "")}
EOF
}
