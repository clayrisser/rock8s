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
    monitors: ${var.monitors}
nodeplugin:
  httpMetrics:
    containerPort: 8082
storageClass:
  create: true
  name: csi-cephfs-sc
  annotations: {}
  clusterID: ${var.cluster_id}
  fsName: myfs
  pool: ""
  fuseMountOptions: ""
  kernelMountOptions: ""
  mounter: ""
  volumeNamePrefix: ""
  provisionerSecret: csi-cephfs-secret
  provisionerSecretNamespace: ""
  controllerExpandSecret: csi-cephfs-secret
  controllerExpandSecretNamespace: ""
  nodeStageSecret: csi-cephfs-secret
  nodeStageSecretNamespace: ""
  reclaimPolicy: Delete
  allowVolumeExpansion: true
  mountOptions: []
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
    monitors: ${var.monitors}
nodeplugin:
  httpMetrics:
    containerPort: 8083
storageClass:
  create: true
  name: csi-rbd-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  clusterID: ${var.cluster_id}
  dataPool: ""
  pool: replicapool
  imageFeatures: "layering"
  mounter: ""
  cephLogDir: ""
  cephLogStrategy: ""
  volumeNamePrefix: ""
  encrypted: ""
  encryptionKMSID: ""
  topologyConstrainedPools: []
  mapOptions: ""
  unmapOptions: ""
  stripeUnit: ""
  stripeCount: ""
  objectSize: ""
  provisionerSecret: csi-rbd-secret
  provisionerSecretNamespace: ""
  controllerExpandSecret: csi-rbd-secret
  controllerExpandSecretNamespace: ""
  nodeStageSecret: csi-rbd-secret
  nodeStageSecretNamespace: ""
  fstype: ext4
  reclaimPolicy: Delete
  allowVolumeExpansion: true
  mountOptions: []
EOF
  ]
}
