/**
 * File: /hetzner.tf
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

resource "kubernetes_cluster_role" "cert_manager_webhook_hetzner_configmap_reader" {
  count = (var.enabled && try(var.issuers.hetzner.api_key != "", false)) ? 1 : 0
  metadata {
    name = "cert-manager-webhook-hetzner-configmap-reader"
  }
  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    verbs          = ["get", "list", "watch"]
    resource_names = ["extension-apiserver-authentication"]
  }
}

resource "kubernetes_cluster_role_binding" "cert_manager_webhook_hetzner_configmap_reader" {
  count = (var.enabled && try(var.issuers.hetzner.api_key != "", false)) ? 1 : 0
  metadata {
    name = "cert-manager-webhook-hetzner-configmap-reader"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cert-manager-webhook-hetzner-configmap-reader"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager-webhook-hetzner"
    namespace = "cert-manager"
  }
}

resource "helm_release" "cert-manager-webhook-hetzner" {
  count            = (var.enabled && try(var.issuers.hetzner.api_key != "", false)) ? 1 : 0
  name             = "cert-manager-webhook-hetzner"
  repository       = "https://vadimkim.github.io/cert-manager-webhook-hetzner"
  chart            = "cert-manager-webhook-hetzner"
  namespace        = var.namespace
  create_namespace = true
  values           = []
  depends_on = [
    kubernetes_cluster_role.cert_manager_webhook_hetzner_configmap_reader,
    kubernetes_cluster_role_binding.cert_manager_webhook_hetzner_configmap_reader
  ]
}

resource "kubectl_manifest" "hetzner-secret" {
  count     = (var.enabled && try(var.issuers.hetzner.api_key != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: hetzner-api-key
  namespace: ${var.namespace}
type: Opaque
stringData:
  api-key: '${try(var.issuers.hetzner.api_key, "")}'
EOF
}

resource "kubectl_manifest" "hetzner-prod" {
  count     = (var.enabled && try(var.issuers.hetzner.api_key != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: hetzner-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: hetzner-prod-account-key
    solvers:
      - dns01:
          webhook:
            groupName: acme.dns.hetzner.com
            solverName: hetzner
            config:
              secretName: hetzner-secret
              apiUrl: https://dns.hetzner.com/api/v1
EOF
  depends_on = [
    kubectl_manifest.hetzner-secret
  ]
}

resource "kubectl_manifest" "hetzner-staging" {
  count     = (var.enabled && try(var.issuers.hetzner.api_key != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: hetzner-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: hetzner-staging-account-key
    solvers:
      - dns01:
          webhook:
            groupName: acme.dns.hetzner.com
            solverName: hetzner
            config:
              secretName: hetzner-secret
              apiUrl: https://dns.hetzner.com/api/v1
EOF
  depends_on = [
    kubectl_manifest.hetzner-secret
  ]
}
