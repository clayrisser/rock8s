module "ceph" {
  source     = "./modules/ceph"
  enabled    = var.ceph
  admin_id   = var.ceph_admin_id
  admin_key  = var.ceph_admin_key
  cluster_id = var.ceph_cluster_id
  fs_name    = var.ceph_fs_name
  monitors   = var.ceph_monitors
  pool       = var.ceph_rbd_pool
}
