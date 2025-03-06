/**
 * File: /main.tf
 * Project: ingress_nginx
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

resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  name             = "ingress-nginx"
  version          = var.chart_version
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
tcp: {}
udp: {}
controller:
  kind: DaemonSet
  watchIngressWithoutClass: true
  hostPort:
    enabled: true
    ports: ${jsonencode({ for port in var.ingress_ports : port == "80" ? "http" : port == "443" ? "https" : port => port })}
  admissionWebhooks:
    enabled: false
  ingressClassResource:
    name: nginx
    default: true
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/instance: ingress-nginx-external
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/instance: ingress-nginx-external
EOF
    ,
    var.load_balancer ? <<EOF
controller:
  kind: DaemonSet
  service:
    enabled: true
    type: LoadBalancer
    ports: ${jsonencode({ for port in var.ingress_ports : port == "80" ? "http" : port == "443" ? "https" : port => port })}
EOF
    : "",
    var.security_group != "" ? <<EOF
controller:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
      service.beta.kubernetes.io/aws-load-balancer-security-groups: ${var.security_group}
      service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules: true
    loadBalancerClass: service.k8s.aws/nlb
EOF
    : "",
    var.replicas > 0 ? <<EOF
controller:
  replicaCount: ${var.replicas}
  minAvailable: ${var.replicas}
EOF
    : "",
    var.values
  ]
}

data "kubernetes_service" "ingress-nginx" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [
    helm_release.this
  ]
}
