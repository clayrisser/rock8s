/**
 * File: /main.tf
 * Project: olm
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

data "kubectl_path_documents" "olm-crds" {
  count   = var.enabled ? 1 : 0
  pattern = "${path.module}/artifacts/olm/crds.yaml"
}

resource "kubectl_manifest" "olm-crds" {
  count = var.enabled ? length(flatten(toset([
    for f in fileset(".", data.kubectl_path_documents.olm-crds[0].pattern) : split("\n---\n", file(f))
  ]))) : 0
  yaml_body         = var.enabled ? element(data.kubectl_path_documents.olm-crds[0].documents, count.index) : null
  server_side_apply = true
  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

data "kubectl_path_documents" "olm" {
  count   = var.enabled ? 1 : 0
  pattern = "${path.module}/artifacts/olm/olm.yaml"
}

resource "kubectl_manifest" "olm" {
  count = var.enabled ? length(flatten(toset([
    for f in fileset(".", data.kubectl_path_documents.olm[0].pattern) : split("\n---\n", file(f))
  ]))) : 0
  yaml_body         = var.enabled ? element(data.kubectl_path_documents.olm[0].documents, count.index) : null
  force_conflicts   = true
  server_side_apply = true
  depends_on = [
    kubectl_manifest.olm-crds
  ]
  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

resource "kubectl_manifest" "auth-delegator" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:auth-delegator
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
rules:
- apiGroups:
    - authentication.k8s.io
  resources:
    - tokenreviews
  verbs:
    - create
- apiGroups:
    - authorization.k8s.io
  resources:
    - subjectaccessreviews
  verbs:
    - create
EOF
  depends_on = [
    kubectl_manifest.olm
  ]
}

resource "kubectl_manifest" "extension-apiserver-authentication-reader" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: extension-apiserver-authentication-reader
  namespace: kube-system
  annotations:
    openshift.io/reconcile-protect: "false"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
rules:
- apiGroups:
    - ""
  attributeRestrictions: null
  resourceNames:
    - extension-apiserver-authentication
  resources:
    - configmaps
  verbs:
    - get
EOF
  depends_on = [
    kubectl_manifest.olm
  ]
}

resource "helm_release" "easy-olm-operator" {
  count      = var.enabled ? 1 : 0
  name       = "easy-olm-operator"
  version    = "0.0.1"
  repository = "https://charts.rock8s.com"
  chart      = "easy-olm-operator"
  namespace  = "kube-system"
  values = [<<EOF
EOF
  ]
  depends_on = [
    kubectl_manifest.olm
  ]
}
