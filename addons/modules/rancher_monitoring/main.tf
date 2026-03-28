resource "helm_release" "crds" {
  count            = var.enabled ? 1 : 0
  name             = "rancher-monitoring-crd"
  chart            = "rancher-monitoring-crd"
  version          = var.chart_version
  repository       = "https://charts.rancher.io"
  namespace        = var.namespace
  create_namespace = var.create_namespace
  wait             = true
}

resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  name             = "rancher-monitoring"
  chart            = "rancher-monitoring"
  version          = var.chart_version
  repository       = "https://charts.rancher.io"
  namespace        = var.namespace
  create_namespace = var.create_namespace
  wait             = true
  values = [
    <<EOF
grafana:
  sidecar:
    dashboards:
      searchNamespace: ALL
  persistence:
    size: 1Gi
    type: pvc
    accessModes:
      - ReadWriteOnce
prometheus:
  prometheusSpec:
    scrapeInterval: 2m
    evaluationInterval: 2m
    retention: ${var.retention}
    retentionSize: ${var.retention_size}
    storageSpec:
      volumeClaimTemplate:
        spec:
          volumeMode: Filesystem
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 10Gi
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: kubernetes.io/arch
                  operator: In
                  values:
                    - amd64
  serviceAccount:
    create: true
prometheusOperator:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                  - amd64
prometheus-adapter:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                  - amd64
kube-state-metrics:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                  - amd64
prometheus-node-exporter:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: eks.amazonaws.com/compute-type
                operator: NotIn
                values:
                  - fargate
EOF
  ]
  depends_on = [
    helm_release.crds
  ]
}

resource "time_sleep" "this" {
  count           = var.enabled ? 1 : 0
  create_duration = "15s"
  depends_on = [
    helm_release.this
  ]
}
