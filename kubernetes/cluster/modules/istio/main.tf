/**
 * File: /main.tf
 * Project: istio
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

resource "helm_release" "base" {
  count            = var.enabled ? 1 : 0
  name             = "istio-base"
  version          = var.chart_version
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
defaultRevision: default
EOF
  ]
}

resource "helm_release" "cni" {
  count      = var.enabled ? 1 : 0
  name       = "istio-cni"
  version    = var.chart_version
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "cni"
  namespace  = "kube-system"
  values = [<<EOF
cni:
  chained: true
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
    helm_release.base
  ]
}

resource "helm_release" "istiod" {
  count            = var.enabled ? 1 : 0
  name             = "istiod"
  version          = var.chart_version
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
istio_cni:
  enabled: true
  chained: true
EOF
    ,
    var.values
  ]
  depends_on = [
    helm_release.cni
  ]
}

resource "helm_release" "kiali" {
  count      = var.enabled ? 1 : 0
  name       = "kiali-server"
  version    = "1.73.0"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  namespace  = var.namespace
  values = [<<EOF
auth:
  strategy: anonymous
EOF
  ]
  depends_on = [
    helm_release.istiod
  ]
}
