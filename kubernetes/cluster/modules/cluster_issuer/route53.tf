/**
 * File: /route53.tf
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

resource "kubectl_manifest" "route53-prod" {
  count = (lookup(var.issuers, "route53", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: route53-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: route53-prod-account-key
    solvers:
      - dns01:
          route53:
            region: ${lookup(var.issuers, "route53", null) != null ?
var.issuers.route53.region : ""}
EOF
}

resource "kubectl_manifest" "route53-staging" {
  count = (lookup(var.issuers, "route53", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: route53-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: route53-staging-account-key
    solvers:
      - dns01:
          route53:
            region: ${lookup(var.issuers, "route53", null) != null ?
var.issuers.route53.region : ""}
EOF
}
