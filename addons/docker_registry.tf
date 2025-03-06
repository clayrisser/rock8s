locals {
  gitlab_registry = "registry.${var.gitlab_hostname}"
}

resource "kubernetes_secret" "registry" {
  metadata {
    name      = "registry"
    namespace = "kube-system"
  }
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${local.gitlab_registry}" = {
          auth = "${base64encode("${var.gitlab_username}:${var.gitlab_token}")}"
        }
      }
    })
  }
  type = "kubernetes.io/dockerconfigjson"
}

resource "kubectl_manifest" "sync-registry" {
  count     = var.kyverno ? 1 : 0
  yaml_body = <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sync-registry
spec:
  background: true
  mutateExistingOnPolicyUpdate: true
  rules:
    - name: sync-registry
      match:
        resources:
          kinds:
            - Namespace
      generate:
        apiVersion: v1
        kind: Secret
        name: ${kubernetes_secret.registry.metadata.0.name}
        namespace: '{{request.object.metadata.name}}'
        synchronize: true
        clone:
          namespace: ${kubernetes_secret.registry.metadata.0.namespace}
          name: ${kubernetes_secret.registry.metadata.0.name}
EOF
  depends_on = [
    module.kyverno,
  ]
}
