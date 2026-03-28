module "vault" {
  source  = "./modules/vault"
  enabled = var.vault != null
  values  = <<EOF
EOF
}
