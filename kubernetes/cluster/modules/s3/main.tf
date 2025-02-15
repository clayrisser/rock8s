/**
 * File: /main.tf
 * Project: external_dns
 * File Created: 27-09-2023 06:47:50
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

resource "helm_release" "s3" {
  count            = var.enabled ? 1 : 0
  name             = "s3"
  version          = var.chart_version
  repository       = "https://charts.rock8s.com"
  chart            = "s3"
  namespace        = var.namespace
  create_namespace = true
  values           = [var.values]
}
