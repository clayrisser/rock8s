module "ceph-csi" {
  source     = "./modules/ceph_csi"
  enabled    = var.ceph
  admin_id   = var.ceph_admin_id
  admin_key  = var.ceph_admin_key
  cluster_id = var.ceph_cluster_id
  monitors   = var.ceph_monitors
}
