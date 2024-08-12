/**
 * File: /main.tf
 * Project: rancher_monitoring
 * File Created: 27-09-2023 05:26:35
 * Author: Clay Risser
 * -----
 * BitSpur (c) Copyright 2021 - 2023
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  namespace = (var.enabled && var.create_namespace) ? rancher2_namespace.this[0].name : var.namespace
  thanos    = var.enabled && var.thanos && var.bucket != ""
}

resource "rancher2_namespace" "this" {
  count      = (var.enabled && var.create_namespace) ? 1 : 0
  name       = var.namespace
  project_id = var.rancher_project_id
}

resource "helm_release" "thanos" {
  count      = local.thanos ? 1 : 0
  name       = "thanos"
  version    = "12.13.7"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "thanos"
  namespace  = local.namespace
  values = [<<EOF
objstoreConfig: |
  type: s3
  config:
    bucket: ${var.bucket}
    endpoint: ${var.endpoint}
    access_key: ${var.access_key}
    secret_key: ${var.secret_key}
    aws_sdk_auth: ${(var.bucket != "" && (var.access_key == "" || var.secret_key == "")) ? "true" : ""}
querier:
  stores:
    - rancher-monitoring-thanos-discovery.cattle-monitoring-system.svc.cluster.local:10901
bucketweb:
  enabled: true
compactor:
  enabled: true
  retentionResolutionRaw: ${var.retention}
  retentionResolution5m: ${var.retention_resolution_5m}
  retentionResolution1h: ${var.retention_resolution_1h}
storegateway:
  enabled: true
EOF
  ]
  depends_on = [
    rancher2_namespace.this
  ]
}

resource "kubectl_manifest" "thanos-datasource" {
  count     = local.thanos ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: thanos-datasource
  namespace: ${local.namespace}
  labels:
    grafana_datasource: '1'
data:
  thanos-datasource.yaml: |-
    apiVersion: 1
    datasources:
      - name: Thanos
        uid: thanos
        type: prometheus
        url: http://thanos-query.cattle-monitoring-system:9090
        access: proxy
        version: 1
EOF
  depends_on = [
    helm_release.thanos
  ]
}

resource "rancher2_app_v2" "this" {
  count         = var.enabled ? 1 : 0
  chart_name    = "rancher-monitoring"
  chart_version = var.chart_version
  cluster_id    = var.rancher_cluster_id
  name          = "rancher-monitoring"
  namespace     = local.namespace
  repo_name     = "rancher-charts"
  wait          = true
  values = <<EOF
grafana:
  sidecar:
    dashboards:
      searchNamespace: ALL
  persistence:
    size: 1Gi
    storageClassName: gp2
    type: pvc
    accessModes:
      - ReadWriteOnce
prometheus:
  prometheusSpec:
    scrapeInterval: 2m
    evaluationInterval: 2m
    retention: ${var.retention}
    retentionSize: ${var.retention_size}
    disableCompaction: ${local.thanos ? "true" : ""}
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp2
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
${local.thanos != "" ? <<EOF
    thanos:
      objectStorageConfig:
        name: bucket-config
        key: objstore.yml
EOF
  : ""}
  serviceAccount:
    create: true
  thanosRuler:
    enabled: ${local.thanos != "" ? "true" : "false"}
  thanosService:
    enabled: ${local.thanos != "" ? "true" : "false"}
${local.thanos != "" ? <<EOF
  extraSecret:
    name: bucket-config
    data:
      objstore.yml: |
        type: S3
        config:
          bucket: ${var.bucket}
          endpoint: ${var.endpoint}
          access_key: ${var.access_key}
          secret_key: ${var.secret_key}
          aws_sdk_auth: ${(var.bucket != "" && (var.access_key == "" || var.secret_key == "")) ? "true" : ""}
          insecure: false
EOF
: ""}
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
depends_on = [
  kubectl_manifest.thanos-datasource
]
}

resource "time_sleep" "this" {
  count           = var.enabled ? 1 : 0
  create_duration = "15s"
  depends_on = [
    rancher2_app_v2.this
  ]
}
