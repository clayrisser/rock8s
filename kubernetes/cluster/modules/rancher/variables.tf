/**
 * File: /variables.tf
 * Project: rancher
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

variable "rancher_cluster_id" {
  default = "local"
}

variable "rancher_admin_password" {
  default = "rancherP@ssw0rd"
}

variable "chart_version" {
  default = "v2.8.0"
}

variable "namespace" {
  default = "cattle-system"
}

variable "values" {
  default = ""
}

variable "rancher_token" {
  default = ""
}

variable "letsencrypt_email" {
  type = string
}

variable "rancher_hostname" {
  type = string
}

variable "kubeconfig" {
  type = string
}
