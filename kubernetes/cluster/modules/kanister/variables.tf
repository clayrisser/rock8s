/**
 * File: /variables.tf
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

variable "enabled" {
  default = true
}

variable "namespace" {
  default = "kanister"
}

variable "chart_version" {
  default = "0.93.0"
}

variable "rancher_cluster_id" {
  type = string
}

variable "rancher_project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "prefix" {
  default = ""
}

variable "bucket" {
  type = string
}

variable "rock8s_repo" {
  type = string
}

variable "access_key" {
  type = string
}

variable "secret_key" {
  type      = string
  sensitive = true
}

variable "endpoint" {
  type = string
}
