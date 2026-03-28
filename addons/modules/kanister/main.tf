resource "helm_release" "this" {
  count            = var.enabled ? 1 : 0
  name             = "kanister"
  version          = var.chart_version
  repository       = "https://charts.kanister.io"
  chart            = "kanister-operator"
  namespace        = var.namespace
  create_namespace = true
  values = [<<EOF
EOF
    ,
    var.values
  ]
}
