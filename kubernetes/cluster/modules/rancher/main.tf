locals {
  rancher_bootstrap_password = "rancherP@ssw0rd"
}

provider "rancher2" {
  alias     = "bootstrap"
  bootstrap = true
  insecure  = true
  api_url   = "https://${var.rancher_hostname}"
}

resource "kubectl_manifest" "namespace" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.namespace}
EOF
}

resource "kubectl_manifest" "deployment-toleration-policy" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: deployment-toleration
  namespace: ${kubectl_manifest.namespace[0].name}
spec:
  background: true
  mutateExistingOnPolicyUpdate: true
  rules:
    - name: deployment-toleration
      match:
        resources:
          kinds:
            - apps/*/Deployment
          names:
            - rancher
      mutate:
        targets:
          - apiVersion: apps/v1
            kind: Deployment
            name: rancher
        patchStrategicMerge:
          spec:
            template:
              spec:
                tolerations:
                  - key: node-role.kubernetes.io/control-plane
                    operator: Exists
                    effect: NoSchedule
                affinity:
                  nodeAffinity:
                    requiredDuringSchedulingIgnoredDuringExecution:
                      nodeSelectorTerms:
                        - matchExpressions:
                            - key: node-role.kubernetes.io/control-plane
                              operator: In
                              values:
                                - ''
EOF
}

resource "helm_release" "this" {
  count      = var.enabled ? 1 : 0
  name       = "rancher"
  repository = "https://releases.rancher.com/server-charts/latest"
  chart      = "rancher"
  version    = var.chart_version
  namespace  = kubectl_manifest.namespace[0].name
  values = [<<EOF
replicas: 1
bootstrapPassword: ${local.rancher_bootstrap_password}
hostname: ${var.rancher_hostname}
ingress:
  enabled: true
  extraAnnotations:
    kubernetes.io/ingress.class: nginx
  tls:
    source: letsEncrypt
letsEncrypt:
  enabled: true
  email: ${var.letsencrypt_email}
  environment: production
resources:
  limits:
    cpu: 3
    memory: 4Gi
  requests:
    cpu: 2
    memory: 3Gi
global:
  cattle:
    psp:
      enabled: false
EOF
    ,
    var.values
  ]
  depends_on = [
    kubectl_manifest.deployment-toleration-policy
  ]
}

resource "null_resource" "wait-for-rancher" {
  count = var.enabled ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOF
sleep 15
while [ "$${subject}" != "*  subject: CN=$RANCHER_HOSTNAME" ]; do
    subject=$(curl -vk -m 2 "https://$RANCHER_HOSTNAME/ping" 2>&1 | grep "subject:")
    echo "Cert Subject Response: $${subject}"
    if [ "$${subject}" != "*  subject: CN=$RANCHER_HOSTNAME" ]; then
      sleep 10
    fi
done
while [ "$${resp}" != "pong" ]; do
    resp=$(curl -sSk -m 2 "https://$RANCHER_HOSTNAME/ping")
    echo "Rancher Response: $${resp}"
    if [ "$${resp}" != "pong" ]; then
      sleep 10
    fi
done
sleep 15
EOF
    interpreter = ["bash", "-c"]
    environment = {
      RANCHER_HOSTNAME = var.rancher_hostname
      KUBECONFIG       = var.kubeconfig
    }
  }
  depends_on = [
    helm_release.this
  ]
}

resource "rancher2_bootstrap" "admin" {
  count            = var.enabled ? 1 : 0
  provider         = rancher2.bootstrap
  initial_password = local.rancher_bootstrap_password
  password         = var.rancher_admin_password
  telemetry        = false
  token_update     = false
  depends_on = [
    null_resource.wait-for-rancher
  ]
}

provider "rancher2" {
  alias     = "admin"
  api_url   = "https://${var.rancher_hostname}"
  token_key = var.rancher_token != "" ? var.rancher_token : try(rancher2_bootstrap.admin[0].token, "")
}

resource "rancher2_token" "this" {
  count       = (var.enabled && var.rancher_token == "") ? 1 : 0
  provider    = rancher2.admin
  description = "terraform"
  renew       = true
  ttl         = 0
  depends_on = [
    null_resource.wait-for-rancher
  ]
}

provider "rancher2" {
  api_url   = "https://${var.rancher_hostname}"
  token_key = var.rancher_token != "" ? var.rancher_token : try(rancher2_token.this[0].token, "")
}

data "rancher2_project" "system" {
  count      = var.enabled ? 1 : 0
  cluster_id = var.rancher_cluster_id
  name       = "System"
  depends_on = [
    rancher2_token.this[0]
  ]
}

resource "kubectl_manifest" "rancher-cluster-role" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
EOF
  depends_on = [
    null_resource.wait-for-rancher
  ]
}

resource "kubectl_manifest" "rancher-cluster-role-binding" {
  count     = var.enabled ? 1 : 0
  yaml_body = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: rancher-cluster-admin
subjects:
  - kind: ServiceAccount
    name: rancher
    namespace: cattle-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
  depends_on = [
    kubectl_manifest.rancher-cluster-role
  ]
}
