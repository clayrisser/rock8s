/**
 * File: /main.tf
 * Project: argocd
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

resource "kubectl_manifest" "namespace" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.namespace}
EOF
}

resource "helm_release" "this" {
  count      = var.enabled ? 1 : 0
  repository = "https://argoproj.github.io/argo-helm"
  version    = var.chart_version
  chart      = "argo-cd"
  name       = "argocd"
  namespace  = var.namespace
  values = [<<EOF
global:
  securityContext:
    fsGroup: 999
configs:
  params:
    server.disable.auth: true
dex:
  enabled: false
EOF
    ,
    var.values
  ]
}
