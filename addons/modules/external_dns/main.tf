locals {
  route53_role_arn = try(var.dns_providers.route53.role_arn, "")
  provider = try(
    var.dns_providers.cloudflare.api_key != "" && var.dns_providers.cloudflare.email != "" ? "cloudflare" :
    var.dns_providers.pdns.api_key != "" && var.dns_providers.pdns.api_url != "" ? "pdns" :
    var.dns_providers.hetzner.api_key != "" ? "webhook" :
    var.dns_providers.digitalocean.api_token != "" ? "digitalocean" :
    "aws", "aws"
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
  name             = "external-dns"
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
digitalocean: ${try(jsonencode({
    apiToken = var.dns_providers.digitalocean.api_token
    }), "{}")}
pdns: ${try(jsonencode({
    apiUrl  = regex("^(https?://[^:]+)(?::\\d+)?", var.dns_providers.pdns.api_url)[0]
    apiPort = try(regex(":(\\d+)$", var.dns_providers.pdns.api_url)[0], startswith(lower(var.dns_providers.pdns.api_url), "https") ? 443 : 80)
    apiKey  = var.dns_providers.pdns.api_key
}), "{}")}
EOF
,
try(var.dns_providers.hetzner.api_key != "" ? <<EOF
sidecars: ${jsonencode([{
  name  = "hetzner-webhook",
  image = "ghcr.io/mconfalonieri/external-dns-hetzner-webhook:v0.12.0",
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
