/**
 * File: /main.tf
 * Project: flux
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
  repository       = "https://fluxcd-community.github.io/helm-charts"
  version          = var.chart_version
  chart            = "flux2"
  name             = "flux2"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
EOF
    ,
    var.values
  ]
}

# Capacitor Next — Flux-oriented cluster UI (chart source:
# https://github.com/gimlet-io/capacitor/tree/main/self-host/charts/capacitor-next).
# Published as: oci://ghcr.io/gimlet-io/charts/capacitor-next
resource "helm_release" "capacitor_next" {
  count     = var.enabled && var.capacitor_next_enabled ? 1 : 0
  name      = "capacitor-next"
  chart     = "oci://ghcr.io/gimlet-io/charts/capacitor-next"
  version   = var.capacitor_next_chart_version
  namespace = var.namespace

  depends_on = [helm_release.this]

  values = concat(
    [<<-EOF
    # Chart reads .Values.env.*; a nil env map breaks template render. This key is only for AKS
    # Workload Identity (pod label); "false" is correct for non-Azure clusters.
    env:
      AZURE_WORKLOAD_IDENTITY_ENABLED: "false"
    EOF
    ],
    var.capacitor_next_values != "" ? [var.capacitor_next_values] : []
  )
}
