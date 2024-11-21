/**
 * File: /pdns.tf
 * Project: cluster_issuer
 * File Created: 27-09-2023 07:10:54
 * Author: Assistant
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

resource "kubernetes_cluster_role" "cert_manager_webhook_pdns_configmap_reader" {
  count = (var.enabled && try(var.issuers.pdns.api_url != "" && var.issuers.pdns.api_key != "", false)) ? 1 : 0
  metadata {
    name = "cert-manager-webhook-pdns-configmap-reader"
  }
  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    verbs          = ["get", "list", "watch"]
    resource_names = ["extension-apiserver-authentication"]
  }
}

resource "kubernetes_cluster_role_binding" "cert_manager_webhook_pdns_configmap_reader" {
  count = (var.enabled && try(var.issuers.pdns.api_url != "" && var.issuers.pdns.api_key != "", false)) ? 1 : 0
  metadata {
    name = "cert-manager-webhook-pdns-configmap-reader"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cert-manager-webhook-pdns-configmap-reader"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager-webhook-pdns"
    namespace = "cert-manager"
  }
}

resource "helm_release" "cert-manager-webhook-pdns" {
  count            = (var.enabled && try(var.issuers.pdns.api_url != "" && var.issuers.pdns.api_key != "", false)) ? 1 : 0
  name             = "cert-manager-webhook-pdns"
  repository       = "https://zachomedia.github.io/cert-manager-webhook-pdns"
  chart            = "cert-manager-webhook-pdns"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
image:
  repository: docker.io/zachomedia/cert-manager-webhook-pdns
  tag: latest
EOF
  ]
  depends_on = [
    kubernetes_cluster_role.cert_manager_webhook_pdns_configmap_reader,
    kubernetes_cluster_role_binding.cert_manager_webhook_pdns_configmap_reader
  ]
}

resource "kubectl_manifest" "pdns-secret" {
  count     = (var.enabled && try(var.issuers.pdns.api_url != "" && var.issuers.pdns.api_key != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: pdns-api-key
  namespace: ${var.namespace}
type: Opaque
stringData:
  key: '${try(var.issuers.pdns.api_key, "")}'
EOF
}

resource "kubectl_manifest" "pdns-prod" {
  count     = (var.enabled && try(var.issuers.pdns.api_url != "" && var.issuers.pdns.api_key != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: pdns-prod
spec:
  acme:
    server: 'https://acme-v02.api.letsencrypt.org/directory'
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: pdns-prod-account-key
    solvers:
      - dns01:
          webhook:
            groupName: acme.zacharyseguin.ca
            solverName: pdns
            config:
              host: ${try(var.issuers.pdns.api_url, "")}
              apiKeySecretRef:
                name: pdns-api-key
                key: key
EOF
  depends_on = [
    kubectl_manifest.pdns-secret,
    helm_release.cert-manager-webhook-pdns
  ]
}

resource "kubectl_manifest" "pdns-staging" {
  count     = (var.enabled && try(var.issuers.pdns.api_url != "" && var.issuers.pdns.api_key != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: pdns-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: pdns-staging-account-key
    solvers:
      - dns01:
          webhook:
            groupName: acme.zacharyseguin.ca
            solverName: pdns
            config:
              host: ${try(var.issuers.pdns.api_url, "")}
              apiKeySecretRef:
                name: pdns-api-key
                key: key
EOF
  depends_on = [
    kubectl_manifest.pdns-secret,
    helm_release.cert-manager-webhook-pdns
  ]
}
