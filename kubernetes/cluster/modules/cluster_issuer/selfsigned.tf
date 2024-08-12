/**
 * File: /selfsigned.tf
 * Project: cluster_issuer
 * File Created: 27-09-2023 07:10:54
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

resource "kubectl_manifest" "selfsigned-issuer" {
  count     = (lookup(var.issuers, "selfsigned", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  ca:
    secretName: selfsigned-ca
EOF
}

resource "tls_private_key" "selfsigned-ca" {
  count     = (lookup(var.issuers, "selfsigned", null) != null && var.enabled) ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "selfsigned-ca" {
  count                 = (lookup(var.issuers, "selfsigned", null) != null && var.enabled) ? 1 : 0
  private_key_pem       = tls_private_key.selfsigned-ca[0].private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 24 * 356
  subject {
    common_name = "selfsigned-ca"
  }
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "cert_signing",
    "server_auth",
    "client_auth"
  ]
}

resource "kubectl_manifest" "selfsigned-secret" {
  count     = (lookup(var.issuers, "selfsigned", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: selfsigned-ca
  namespace: kube-system
type: kubernetes.io/tls
data:
  tls.crt: ${base64encode(tls_self_signed_cert.selfsigned-ca[0].cert_pem)}
  tls.key: ${base64encode(tls_private_key.selfsigned-ca[0].private_key_pem)}
EOF
  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}
