/**
 * File: /variables.tf
 * Project: external_dns
 * File Created: 27-09-2023 06:50:24
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
  default = "external-dns"
}

variable "chart_version" {
  default = "8.4.0"
}

variable "values" {
  default = ""
}

variable "dns_providers" {
  default = {
    cloudflare = null
    aws        = null
    pdns       = null
  }
}

variable "default_targets" {
  type    = list(string)
  default = []
}
