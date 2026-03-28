resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  repository       = "https://kyverno.github.io/kyverno"
  version          = var.chart_version
  chart            = "kyverno"
  name             = "kyverno"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
admissionController:
  replicas: 1
backgroundController:
  replicas: 1
  resources:
    limits:
      memory: 300Mi
cleanupController:
  replicas: 1
reportsController:
  replicas: 1
EOF
    ,
    var.values
  ]
}
