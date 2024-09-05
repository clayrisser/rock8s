/**
 * File: /main.tf
 * Project: argocd
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

resource "kubectl_manifest" "namespace" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.namespace}
EOF
}

resource "helm_release" "this" {
  count      = var.enabled ? 1 : 0
  repository = "https://argoproj.github.io/argo-helm"
  version    = var.chart_version
  chart      = "argo-cd"
  name       = "argocd"
  namespace  = var.namespace
  values = [<<EOF
global:
  securityContext:
    fsGroup: 999
configs:
  params:
    server.disable.auth: true
  cmp:
    create: true
    plugins:
      avp:
        discover:
          find:
            command: 
              - sh
              - "-c"
              - "find . -name '*.yaml'"
        generate:
          command:
            - argocd-vault-plugin"
            - generate
            - "."
repoServer:
  volumes:
    - name: custom-tools
      emptyDir: {}
    - name: cmp-plugin
      configMap:
        name: argocd-cmp-cm
  volumeMounts:
    - name: custom-tools
      mountPath: /usr/local/bin/argocd-vault-plugin
      subPath: argocd-vault-plugin
  extraContainers:
    - name: avp
      command: [/var/run/argocd/argocd-cmp-server]
      image: quay.io/argoproj/argocd:v2.7.2
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
      volumeMounts:
        - mountPath: /var/run/argocd
          name: var-files
        - mountPath: /home/argocd/cmp-server/plugins
          name: plugins
        - mountPath: /tmp
          name: tmp
        - mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: avp.yaml
          name: cmp-plugin
        - name: custom-tools
          subPath: argocd-vault-plugin
          mountPath: /usr/local/bin/argocd-vault-plugin
  initContainers:
    - name: download-tools
      image: alpine:3.8
      command: [sh, -c]
      env:
        - name: AVP_VERSION
          value: "1.14.0"
      args:
        - >-
          wget -O argocd-vault-plugin
          https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v$${AVP_VERSION}/argocd-vault-plugin_$${AVP_VERSION}_linux_amd64 &&
          chmod +x argocd-vault-plugin &&
          mv argocd-vault-plugin /custom-tools/
      volumeMounts:
        - mountPath: /custom-tools
          name: custom-tools
EOF
    ,
    var.values
  ]
}
