/**
 * File: /main.tf
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

resource "kubectl_manifest" "letsencrypt-prod" {
  count     = (lookup(var.issuers, "letsencrypt", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
            ingressTemplate:
              metadata:
                annotations:
                  acme.cert-manager.io/http01-edit-in-place: 'true'
                  kubernetes.io/ingress.class: nginx
EOF
}

resource "kubectl_manifest" "letsencrypt-staging" {
  count     = (lookup(var.issuers, "letsencrypt", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
            ingressTemplate:
              metadata:
                annotations:
                  acme.cert-manager.io/http01-edit-in-place: 'true'
                  kubernetes.io/ingress.class: nginx
EOF
}
