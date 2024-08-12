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

resource "rancher2_namespace" "this" {
  count      = var.enabled ? 1 : 0
  name       = var.namespace
  project_id = var.rancher_project_id
}

resource "rancher2_app_v2" "this" {
  count         = var.enabled ? 1 : 0
  chart_name    = "kanister"
  chart_version = var.chart_version
  cluster_id    = var.rancher_cluster_id
  name          = "kanister"
  namespace     = rancher2_namespace.this[0].name
  repo_name     = var.rock8s_repo
  wait          = true
  values        = <<EOF
config:
  s3:
    accessKey: '${var.access_key}'
    bucket: '${var.bucket}'
    endpoint: '${var.endpoint}'
    prefix: '${var.prefix}'
    region: '${var.region}'
    secretKey: '${var.secret_key}'
EOF
}
