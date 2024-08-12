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
locals {
  route53_role_arn = (lookup(var.dns_providers, "route53", null) != null ?
    (lookup(var.dns_providers.route53, "roleArn", null) != null ?
  var.dns_providers.route53.roleArn : "") : "")
}

resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  name             = "external-dns"
  version          = var.chart_version
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "external-dns"
  namespace        = var.namespace
  create_namespace = true
  values = concat(
    (local.route53_role_arn != "" ? [
      <<EOF
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: ${local.route53_role_arn}
EOF
    ] : []),
    [
      <<EOF
provider: ${lookup(var.dns_providers, "route53", null) != null ? "aws" : "cloudflare"}
aws:
  region: ${lookup(var.dns_providers, "route53", null) != null ?
      var.dns_providers.route53.region : ""}
  credentials:
    secretKey: ${lookup(var.dns_providers, "route53", null) != null ?
      (lookup(var.dns_providers.route53, "secretKey", null) != null ?
      var.dns_providers.route53.secretKey : "") : ""}
    accessKey: ${lookup(var.dns_providers, "route53", null) != null ?
      (lookup(var.dns_providers.route53, "accessKey", null) != null ?
      var.dns_providers.route53.accessKey : "") : ""}
cloudflare:
  apiKey: ${lookup(var.dns_providers, "cloudflare", null) != null ?
      var.dns_providers.cloudflare.apiKey : ""}
  email: ${lookup(var.dns_providers, "cloudflare", null) != null ?
    var.dns_providers.cloudflare.email : ""}
  proxied: false
sources:
  - ingress
EOF
    ,
    var.values
])
}
