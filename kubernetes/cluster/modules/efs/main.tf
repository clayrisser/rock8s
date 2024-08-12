/**
 * File: /main.tf
 * Project: efs
 * File Created: 27-01-2024 04:28:11
 * Author: Clay Risser
 * -----
 * BitSpur (c) Copyright 2021 - 2024
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

# https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
# https://medium.com/codex/irsa-implementation-in-kops-managed-kubernetes-cluster-18cef84960b6

resource "helm_release" "aws_efs_csi_driver" {
  count            = var.enabled ? 1 : 0
  version          = "2.2.9"
  name             = "aws-efs-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  chart            = "aws-efs-csi-driver"
  namespace        = "kube-system"
  create_namespace = true
  values = [<<EOF
image:
  repository: 602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-efs-csi-driver
controller:
  logLevel: 2
  serviceAccount:
    create: true
    name: efs-csi-controller-sa
    annotations:
      eks.amazonaws.com/role-arn: ${var.role_arn}
de:
  logLevel: 2
  serviceAccount:
    create: true
    name: efs-csi-node-sa
    annotations:
      eks.amazonaws.com/role-arn: ${var.role_arn}
storageClasses:
  - name: efs-sc
    mountOptions:
      - tls
    parameters:
      basePath: /dynamic_provisioning
      directoryPerms: '700'
      fileSystemId: ${var.file_system_id}
      gid: '1000'
      gidRangeEnd: '2000'
      gidRangeStart: '1000'
      provisioningMode: efs-ap
      uid: '1000'
    reclaimPolicy: Delete
    volumeBindingMode: Immediate
EOF
  ]
}
