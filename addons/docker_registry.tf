resource "kubernetes_secret" "registry" {
  count = length(var.registries) > 0 ? 1 : 0
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
  count     = length(var.registries) > 0 ? 1 : 0
  yaml_body = <<EOF
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: ${kubernetes_secret.registry[0].metadata.0.name}
spec:
  background: true
  mutateExistingOnPolicyUpdate: true
  rules:
    - name: sync-registry
      match:
        resources:
          kinds:
            - v1/Pod
      mutate:
        targets:
          - apiVersion: v1
            kind: Pod
        patchStrategicMerge:
          spec:
            imagePullSecrets:
              - name: ${kubernetes_secret.registry[0].metadata.0.name}
            containers:
              - (name): "*"
                imagePullSecrets:
                  - namespace: ${kubernetes_secret.registry[0].metadata.0.namespace}
                    name: ${kubernetes_secret.registry[0].metadata.0.name}
EOF
}
