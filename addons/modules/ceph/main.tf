resource "helm_release" "cephfs" {
  count            = var.enabled ? 1 : 0
  name             = "ceph-csi-cephfs"
  chart            = "ceph-csi-cephfs"
  version          = var.cephfs_version
  repository       = "https://ceph.github.io/csi-charts"
  namespace        = "ceph-csi-cephfs"
  create_namespace = true
  wait             = true
  values = [
    <<EOF
secret:
  create: true
  name: csi-cephfs-secret
  adminID: ${var.admin_id}
  adminKey: ${var.admin_key}
csiConfig:
  - clusterID: ${var.cluster_id}
    monitors: ${join(",", var.monitors)}
nodeplugin:
  httpMetrics:
    containerPort: 8082
provisioner:
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
topology:
  domainLabels:
    - topology.kubernetes.io/zone
storageClass:
  create: true
  clusterID: ${var.cluster_id}
  fsName: ${var.fs_name}
EOF
  ]
}

resource "helm_release" "rbd" {
  count            = var.enabled ? 1 : 0
  name             = "ceph-csi-rbd"
  chart            = "ceph-csi-rbd"
  version          = var.rbd_version
  repository       = "https://ceph.github.io/csi-charts"
  namespace        = "ceph-csi-rbd"
  create_namespace = true
  wait             = true
  values = [
    <<EOF
secret:
  create: true
  name: csi-rbd-secret
  userID: ${var.admin_id}
  userKey: ${var.admin_key}
csiConfig:
  - clusterID: ${var.cluster_id}
    monitors: ${join(",", var.monitors)}
nodeplugin:
  httpMetrics:
    containerPort: 8083
provisioner:
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
topology:
  domainLabels:
    - topology.kubernetes.io/zone
storageClass:
  create: true
  clusterID: ${var.cluster_id}
  annotations:
    storageclass.kubernetes.io/is-default-class: 'true'
  pool: ${var.pool}
EOF
  ]
}
