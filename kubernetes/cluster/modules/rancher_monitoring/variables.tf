/**
 * File: /variables.tf
 * Project: rancher_monitoring
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
  default = "cattle-monitoring-system"
}

variable "chart_version" {
  default = "102.0.2+up40.1.2"
}

variable "endpoint" {
  default = "us-east-1"
}

variable "retention" {
  default = "168h" # 7 days
}

variable "retention_size" {
  default = "1GiB"
}

variable "retention_resolution_5m" {
  default = "720h" # 30 days
}

variable "retention_resolution_1h" {
  default = "8766h" # 1 year
}

variable "access_key" {
  default = ""
}

variable "secret_key" {
  default   = ""
  sensitive = true
}

variable "bucket" {
  default = ""
}

variable "thanos" {
  default = false
}

variable "create_namespace" {
  default = true
}

variable "rancher_cluster_id" {
  type = string
}

variable "rancher_project_id" {
  type = string
}
