/**
 * File: /cloudflare.tf
 * Project: cluster_issuer
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

resource "kubectl_manifest" "cloudflare-secret" {
  count = (lookup(var.issuers, "cloudflare", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare
  namespace: kube-system
type: Opaque
stringData:
  cloudflare_api_key: '${lookup(var.issuers, "cloudflare", null) != null ?
lookup(var.issuers.cloudflare, "api_key", "") : ""}'
EOF
}

resource "kubectl_manifest" "cloudflare-prod" {
  count = (lookup(var.issuers, "cloudflare", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: cloudflare-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            email: ${lookup(var.issuers, "cloudflare", null) != null ?
  (lookup(var.issuers.cloudflare, "email", null) != null ?
var.issuers.cloudflare.email : var.letsencrypt_email) : ""}
            apiKeySecretRef:
              name: cloudflare
              key: cloudflare_api_key
EOF
depends_on = [
  kubectl_manifest.cloudflare-secret
]
}

resource "kubectl_manifest" "cloudflare-staging" {
  count = (lookup(var.issuers, "cloudflare", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: cloudflare-staging-account-key
    solvers:
      - dns01:
          cloudflare:
            email: ${lookup(var.issuers, "cloudflare", null) != null ?
  (lookup(var.issuers.cloudflare, "email", null) != null ?
var.issuers.cloudflare.email : var.letsencrypt_email) : ""}
            apiKeySecretRef:
              name: cloudflare
              key: cloudflare_api_key
EOF
depends_on = [
  kubectl_manifest.cloudflare-secret
]
}
