# module "kanister" {
#   source             = "./modules/kanister"
#   enabled            = local.kanister
#   rancher_cluster_id = local.rancher_cluster_id
#   rancher_project_id = local.rancher_project_id
#   rock8s_repo        = rancher2_catalog_v2.rock8s[0].name
#   access_key         = var.kanister_access_key
#   bucket             = var.kanister_bucket
#   endpoint           = "s3.us-east-1.amazonaws.com"
#   region             = "us-east-1"
#   secret_key         = var.kanister_secret_key
#   depends_on = [
#     module.kyverno,
#     module.olm
#   ]
# }
