/**
 * File: /main.tf
 * Project: kanister
 * File Created: 03-12-2023 03:42:26
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

resource "helm_release" "operator" {
  count            = var.enabled ? 1 : 0
  name             = "kanister-operator"
  chart            = "kanister-operator"
  version          = var.chart_version
  repository       = "https://charts.rock8s.com"
  namespace        = var.namespace
  create_namespace = true
  wait             = true
}

resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  name             = "kanister"
  chart            = "kanister"
  version          = var.chart_version
  repository       = "https://charts.rock8s.com"
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  values = [
    <<EOF
config:
  s3:
    accessKey: '${var.access_key}'
    bucket: '${var.bucket}'
    endpoint: '${var.endpoint}'
    prefix: '${var.prefix}'
    region: '${var.region}'
    secretKey: '${var.secret_key}'
EOF
    ,
    var.values
  ]
  depends_on = [
    helm_release.operator
  ]
}
