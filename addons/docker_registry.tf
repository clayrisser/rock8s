resource "kubernetes_secret" "registry" {
  metadata {
    name      = "registries"
    namespace = "kube-system"
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        for name, auth in var.registries : name => (
          can(auth.username) ?
          {
            auth = base64encode("${auth.username}:${auth.password}")
          } :
          {
            auth = auth.token
          }
        )
      }
    })
  }
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
