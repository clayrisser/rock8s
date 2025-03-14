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

resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  name             = "longhorn"
  version          = var.chart_version
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
persistence:
  defaultClassReplicaCount: 2
  defaultDataLocality: "best-effort"
defaultSettings:
  guaranteedInstanceManagerCPU: 25
  storageMinimalAvailablePercentage: 10
  concurrentReplicaRebuildPerNodeLimit: 5
  engineReplicaTimeout: 20
  snapshotMaxCount: 10
  backupCompressionMethod: "lz4"
  backupConcurrentLimit: 2
  defaultReplicaCount: 2
  createDefaultDiskLabeledNodes: false
  v2DataEngine: true
service:
  ui:
    type: ClusterIP
longhornUI:
  replicas: 1
EOF
    ,
    var.s3_endpoint != "" && var.s3_bucket != "" ? <<EOF
defaultBackupStore:
  backupTarget: s3://${var.s3_bucket}/
  backupTargetCredentialSecret: longhorn-system
  pollInterval: 300
EOF
    : "",
    var.values
  ]
}

resource "kubernetes_secret" "longhorn_system" {
  count = var.s3_endpoint != "" && var.s3_bucket != "" ? 1 : 0
  metadata {
    name      = "longhorn-system"
    namespace = var.namespace
  }
  type = "Opaque"
  data = {
    AWS_ACCESS_KEY_ID     = var.s3_access_key
    AWS_SECRET_ACCESS_KEY = var.s3_secret_key
    AWS_ENDPOINTS         = var.s3_endpoint
  }
  depends_on = [helm_release.this]
}
