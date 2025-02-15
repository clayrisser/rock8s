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
  route53_role_arn = try(var.dns_providers.route53.roleArn, "")
  provider = try(
    var.dns_providers.cloudflare.api_key != "" && var.dns_providers.cloudflare.email != "" ? "cloudflare" :
    var.dns_providers.pdns.api_key != "" && var.dns_providers.pdns.api_url != "" ? "pdns" :
    var.dns_providers.hetzner.api_key != "" ? "webhook" : "aws", "aws"
  )
}

resource "kubectl_manifest" "hetzner-credentials" {
  count     = var.enabled && try(var.dns_providers.hetzner.api_key != "", false) ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: hetzner-credentials
  namespace: ${var.namespace}
type: Opaque
stringData:
  api-key: ${try(var.dns_providers.hetzner.api_key, "")}
EOF
}

resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  name             = "bitnami"
  version          = var.chart_version
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "external-dns"
  namespace        = var.namespace
  create_namespace = true
  values = [
    local.route53_role_arn != "" ? <<EOF
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${local.route53_role_arn}
    EOF
    : "",
    <<EOF
    provider: ${local.provider}
    aws: ${try(jsonencode({
    region = var.dns_providers.route53.region
    credentials = {
      secretKey = try(var.dns_providers.route53.secret_key, null)
      accessKey = try(var.dns_providers.route53.access_key, null)
    }
    }), "{}")}
    cloudflare: ${try(jsonencode({
    apiKey  = var.dns_providers.cloudflare.api_key
    email   = var.dns_providers.cloudflare.email
    proxied = false
    }), "{}")}
    pdns: ${try(jsonencode({
    apiUrl  = regex("^(https?://[^:]+)(?::\\d+)?", var.dns_providers.pdns.api_url)[0]
    apiPort = try(regex(":(\\d+)$", var.dns_providers.pdns.api_url)[0], startswith(lower(var.dns_providers.pdns.api_url), "https") ? 443 : 80)
    apiKey  = var.dns_providers.pdns.api_key
}), "{}")}
    EOF
,
try(var.dns_providers.hetzner.api_key != "" ? <<EOF
    image: ${jsonencode({
  registry   = "registry.k8s.io",
  repository = "external-dns/external-dns",
  tag        = "v0.14.0"
  })}
    sidecars: ${jsonencode([{
    name  = "hetzner-webhook",
    image = "ghcr.io/mconfalonieri/external-dns-hetzner-webhook:v0.6.0",
    ports = [
      {
        containerPort = 8888,
        name          = "webhook"
      },
      {
        containerPort = 8080,
        name          = "http"
      }
    ],
    livenessProbe = {
      httpGet = {
        path = "/health",
        port = "http"
      },
      initialDelaySeconds = 10,
      timeoutSeconds      = 5
    },
    readinessProbe = {
      httpGet = {
        path = "/ready",
        port = "http"
      },
      initialDelaySeconds = 10,
      timeoutSeconds      = 5
    },
    env = [
      {
        name = "HETZNER_API_KEY",
        valueFrom = {
          secretKeyRef = {
            name = "hetzner-credentials",
            key  = "api-key"
          }
        }
      }
    ]
}])}
    EOF
: "", ""),
<<EOF
sources:
  - ingress
EOF
,
length(var.default_targets) > 0 ? <<EOF
extraArgs:
  default-targets: ${join(",", var.default_targets)}
EOF
: "",
var.values
]
}
