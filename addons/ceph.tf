module "ceph" {
  source     = "./modules/ceph"
  enabled    = var.ceph != null
  admin_id   = try(var.ceph.admin_id, "")
  admin_key  = try(var.ceph.admin_key, "")
  cluster_id = try(var.ceph.cluster_id, "")
  fs_name    = try(var.ceph.fs_name, "cephfs")
  monitors   = try(var.ceph.monitors, [])
  pool       = try(var.ceph.rbd_pool, "rbd")
}
