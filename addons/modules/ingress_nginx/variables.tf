/**
 * File: /variables.tf
 * Project: ingress_nginx
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
  default = "ingress-nginx"
}

variable "chart_version" {
  default = "4.7.0"
}

variable "ingress_ports" {
  default = ["80", "443"]
}

variable "values" {
  default = ""
}

variable "replicas" {
  default = 0
}

variable "security_group" {
  default = ""
}

variable "load_balancer" {
  default = true
}
