/**
 * File: /main.tf
 * Project: kyverno
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

resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  repository       = "https://kyverno.github.io/kyverno"
  version          = var.chart_version
  chart            = "kyverno"
  name             = "kyverno"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
admissionController:
  replicas: 1
backgroundController:
  replicas: 1
  resources:
    limits:
      memory: 300Mi
cleanupController:
  replicas: 1
reportsController:
  replicas: 1
EOF
    ,
    var.values
  ]
}
