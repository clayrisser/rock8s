/**
 * File: /variables.tf
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

variable "enabled" {
  default = true
}

variable "namespace" {
  default = "flux-system"
}

variable "chart_version" {
  default = "2.18.1"
}

variable "values" {
  default = ""
}

variable "capacitor_next_enabled" {
  description = "Install Capacitor Next UI (https://github.com/gimlet-io/capacitor/tree/main/self-host/charts/capacitor-next) alongside Flux."
  type        = bool
  default     = true
}

variable "capacitor_next_chart_version" {
  default = "0.14.0"
}

variable "capacitor_next_values" {
  description = "Extra Helm values YAML merged after rock8s baseline (auth, ingress, etc.)."
  default     = ""
}
