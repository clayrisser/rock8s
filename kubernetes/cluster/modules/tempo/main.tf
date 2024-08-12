/**
 * File: /main.tf
 * Project: rancher_logging
 * File Created: 04-10-2023 19:15:49
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

resource "rancher2_namespace" "this" {
  count      = var.enabled ? 1 : 0
  name       = var.namespace
  project_id = var.rancher_project_id
}

resource "rancher2_app_v2" "this" {
  count         = var.enabled ? 1 : 0
  chart_name    = "tempo"
  chart_version = var.chart_version
  cluster_id    = var.rancher_cluster_id
  name          = "tempo"
  namespace     = rancher2_namespace.this[0].name
  repo_name     = var.grafana_repo
  wait          = true
  values        = <<EOF
replicas: 1
tempo:
  retention: ${var.retention}
  repository: grafana/tempo
  tag: 2.1.1
  resources:
    requests:
      cpu: 50m
      memory: 50Mi
    limits:
      cpu: 500m
      memory: 500Mi
  storage:
    trace:
      backend: s3
      s3:
        bucket: ${var.bucket}
        endpoint: ${var.endpoint}
        access_key: ${var.access_key}
        secret_key: ${var.secret_key}
        insecure: false
  receivers:
    jaeger:
      protocols:
        grpc:
          endpoint: 0.0.0.0:14250
        thrift_binary:
          endpoint: 0.0.0.0:6832
        thrift_compact:
          endpoint: 0.0.0.0:6831
        thrift_http:
          endpoint: 0.0.0.0:14268
    opencensus: {}
    otlp:
      protocols:
        grpc:
          endpoint: "0.0.0.0:4317"
        http:
          endpoint: "0.0.0.0:4318"
EOF
}

resource "kubectl_manifest" "tempo-datasource" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo-datasource
  namespace: cattle-monitoring-system
  labels:
    grafana_datasource: '1'
data:
  tempo-datasource.yaml: |-
    apiVersion: 1
    datasources:
      - name: Tempo
        uid: tempo
        type: tempo
        url: http://tempo.tempo.svc.cluster.local:3100
        access: proxy
        version: 1
        jsonData:
          tracesToLogsV2:
            datasourceUid: 'loki'
            spanStartTimeShift: '1h'
            spanEndTimeShift: '-1h'
            tags: ['job', 'instance', 'pod', 'namespace']
            filterByTraceID: false
            filterBySpanID: false
            customQuery: false
          tracesToMetrics:
            datasourceUid: 'prometheus'
            spanStartTimeShift: '1h'
            spanEndTimeShift: '-1h'
            tags: [{ key: 'service.name', value: 'service' }, { key: 'job' }]
            queries: []
          serviceMap:
            datasourceUid: 'prometheus'
          nodeGraph:
            enabled: true
          search:
            hide: false
          lokiSearch:
            datasourceUid: 'loki'
          traceQuery:
            timeShiftEnabled: true
            spanStartTimeShift: '1h'
            spanEndTimeShift: '-1h'
          spanBar:
            type: 'Tag'
            tag: 'http.path'
EOF
}
