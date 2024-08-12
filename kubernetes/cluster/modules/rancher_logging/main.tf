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

resource "rancher2_namespace" "loki" {
  count      = var.enabled ? 1 : 0
  name       = "loki"
  project_id = var.rancher_project_id
}

resource "rancher2_app_v2" "rancher-logging" {
  count         = var.enabled ? 1 : 0
  chart_name    = "rancher-logging"
  chart_version = var.chart_version
  cluster_id    = var.rancher_cluster_id
  name          = "rancher-logging"
  namespace     = rancher2_namespace.this[0].name
  repo_name     = "rancher-charts"
  wait          = true
  values        = <<EOF
EOF
}

resource "rancher2_app_v2" "loki" {
  count         = var.enabled ? 1 : 0
  chart_name    = "loki"
  chart_version = "5.40.1"
  cluster_id    = var.rancher_cluster_id
  name          = "loki"
  namespace     = rancher2_namespace.loki[0].name
  repo_name     = var.grafana_repo
  wait          = false
  values        = <<EOF
gateway:
  basicAuth:
    enabled: false
read:
  replicas: 2
  persistence:
    size: 1Gi
  resources:
    requests:
      cpu: 50m
      memory: 70Mi
    limits:
      cpu: 500m
      memory: 500Mi
write:
  replicas: 2
  persistence:
    size: 1Gi
  resources:
    requests:
      cpu: 50m
      memory: 50Mi
    limits:
      cpu: 500m
      memory: 500Mi
loki:
  auth_enabled: false
  limits_config:
    retention_period: ${var.retention}
  compactor:
    retention_delete_delay: 2h
    retention_delete_worker_count: 150
    retention_enabled: true
  storage:
    type: s3
    s3:
      endpoint: ${var.endpoint}
      region: ${var.region}
      secretAccessKey: ${var.secret_key}
      accessKeyId: ${var.access_key}
      insecure: false
    bucketNames:
      admin: ${var.bucket}
      chunks: ${var.bucket}
      ruler: ${var.bucket}
EOF
}

resource "kubectl_manifest" "loki-output" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: logging.banzaicloud.io/v1beta1
kind: ClusterOutput
metadata:
  name: loki
  namespace: cattle-logging-system
spec:
  loki:
    url: http://loki-gateway.loki.svc.cluster.local
    configure_kubernetes_labels: true
    buffer:
      timekey: 1m
      timekey_use_utc: true
      timekey_wait: 30s
EOF
  depends_on = [
    rancher2_app_v2.rancher-logging
  ]
}

resource "kubectl_manifest" "cluster-flow" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: logging.banzaicloud.io/v1beta1
kind: ClusterFlow
metadata:
  name: loki-all
  namespace: cattle-logging-system
spec:
  globalOutputRefs:
    - loki
  match:
    - select: {}
EOF
  depends_on = [
    rancher2_app_v2.rancher-logging
  ]
}

resource "kubectl_manifest" "loki-datasource" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-datasource
  namespace: cattle-monitoring-system
  labels:
    grafana_datasource: '1'
data:
  loki-datasource.yaml: |-
    apiVersion: 1
    datasources:
      - name: Loki
        uid: loki
        type: loki
        url: http://loki-gateway.loki.svc.cluster.local
        access: proxy
        version: 1
EOF
}

resource "kubectl_manifest" "logs-dashboard" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    grafana_dashboard: '1'
  name: loki-logs-search
  namespace: ${rancher2_namespace.loki[0].name}
data:
  loki-logs-search.json: |-
    {
      "annotations": {
        "list": [
          {
            "$$hashKey": "object:75",
            "builtIn": 1,
            "datasource": "-- Grafana --",
            "enable": true,
            "hide": true,
            "iconColor": "rgba(0, 211, 255, 1)",
            "name": "Annotations & Alerts",
            "type": "dashboard"
          }
        ]
      },
      "description": "loki logs panel",
      "editable": true,
      "gnetId": 12019,
      "graphTooltip": 0,
      "id": 39,
      "iteration": 1663601370917,
      "links": [],
      "panels": [
        {
          "aliasColors": {},
          "bars": true,
          "dashLength": 10,
          "dashes": false,
          "datasource": "Loki",
          "fieldConfig": {
            "defaults": {
              "links": []
            },
            "overrides": []
          },
          "fill": 1,
          "fillGradient": 0,
          "gridPos": {
            "h": 3,
            "w": 24,
            "x": 0,
            "y": 0
          },
          "hiddenSeries": false,
          "id": 6,
          "legend": {
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": false,
            "total": false,
            "values": false
          },
          "lines": false,
          "linewidth": 1,
          "nullPointMode": "null",
          "options": {
            "alertThreshold": true
          },
          "percentage": false,
          "pluginVersion": "7.5.11",
          "pointradius": 2,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "expr": "sum(count_over_time({namespace=\"$namespace\", instance=~\"$pod\"} |~ \"$search\"[$__interval]))",
              "refId": "A"
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeRegions": [],
          "timeShift": null,
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "$$hashKey": "object:168",
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": false
            },
            {
              "$$hashKey": "object:169",
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": false
            }
          ],
          "yaxis": {
            "align": false,
            "alignLevel": null
          }
        },
        {
          "datasource": "Loki",
          "fieldConfig": {
            "defaults": {},
            "overrides": []
          },
          "gridPos": {
            "h": 25,
            "w": 24,
            "x": 0,
            "y": 3
          },
          "id": 2,
          "maxDataPoints": "",
          "options": {
            "dedupStrategy": "none",
            "showLabels": false,
            "showTime": true,
            "sortOrder": "Descending",
            "wrapLogMessage": true
          },
          "targets": [
            {
              "expr": "{namespace=\"$namespace\", instance=~\"$pod\"} |~ \"$search\"",
              "refId": "A"
            }
          ],
          "timeFrom": null,
          "timeShift": null,
          "title": "Logs Panel",
          "type": "logs"
        },
        {
          "datasource": null,
          "fieldConfig": {
            "defaults": {},
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 24,
            "x": 0,
            "y": 28
          },
          "id": 4,
          "options": {
            "content": "<div style=\"text-align:center\"> For Grafana Loki blog example </div>\n\n\n",
            "mode": "html"
          },
          "pluginVersion": "7.5.11",
          "timeFrom": null,
          "timeShift": null,
          "transparent": true,
          "type": "text"
        }
      ],
      "schemaVersion": 27,
      "style": "dark",
      "tags": [],
      "templating": {
        "list": [
          {
            "allValue": null,
            "current": {
              "selected": true,
              "text": "olm",
              "value": "olm"
            },
            "datasource": "Prometheus",
            "definition": "label_values(kube_pod_info, namespace)",
            "description": null,
            "error": null,
            "hide": 0,
            "includeAll": false,
            "label": null,
            "multi": false,
            "name": "namespace",
            "options": [],
            "query": {
              "query": "label_values(kube_pod_info, namespace)",
              "refId": "Prometheus-namespace-Variable-Query"
            },
            "refresh": 1,
            "regex": "",
            "skipUrlSync": false,
            "sort": 0,
            "tagValuesQuery": "",
            "tags": [],
            "tagsQuery": "",
            "type": "query",
            "useTags": false
          },
          {
            "allValue": ".*",
            "current": {
              "selected": true,
              "tags": [],
              "text": [
                "All"
              ],
              "value": [
                "$__all"
              ]
            },
            "datasource": "Prometheus",
            "definition": "label_values(container_network_receive_bytes_total{namespace=~\"$namespace\"},pod)",
            "description": null,
            "error": null,
            "hide": 0,
            "includeAll": true,
            "label": null,
            "multi": true,
            "name": "pod",
            "options": [],
            "query": {
              "query": "label_values(container_network_receive_bytes_total{namespace=~\"$namespace\"},pod)",
              "refId": "Prometheus-pod-Variable-Query"
            },
            "refresh": 1,
            "regex": "",
            "skipUrlSync": false,
            "sort": 0,
            "tagValuesQuery": "",
            "tags": [],
            "tagsQuery": "",
            "type": "query",
            "useTags": false
          },
          {
            "current": {
              "selected": false,
              "text": "",
              "value": ""
            },
            "description": null,
            "error": null,
            "hide": 0,
            "label": null,
            "name": "search",
            "options": [
              {
                "text": "level=warn",
                "value": "level=warn"
              },
              {
                "text": "level=info",
                "value": "level=info"
              },
              {
                "text": "level=error",
                "value": "level=error"
              }
            ],
            "query": "",
            "skipUrlSync": false,
            "type": "textbox"
          }
        ]
      },
      "time": {
        "from": "now-30m",
        "to": "now"
      },
      "timepicker": {
        "refresh_intervals": [
          "5s",
          "10s",
          "30s",
          "1m",
          "5m",
          "15m",
          "30m",
          "1h",
          "2h",
          "1d"
        ]
      },
      "timezone": "",
      "title": "Logs",
      "uid": "aiF7eehie2",
      "version": 1
    }
EOF
  depends_on = [
    rancher2_app_v2.rancher-logging
  ]
}
