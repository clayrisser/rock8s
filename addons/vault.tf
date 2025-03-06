module "vault" {
  source  = "./modules/vault"
  enabled = var.vault
  values  = <<EOF
EOF
}
