resource "kubectl_manifest" "route53-prod" {
  count     = (var.enabled && try(var.issuers.route53.region != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: route53-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: route53-prod-account-key
    solvers:
      - dns01:
          route53:
            region: ${try(var.issuers.route53.region, "")}
EOF
}

resource "kubectl_manifest" "route53-staging" {
  count     = (var.enabled && try(var.issuers.route53.region != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: route53-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: route53-staging-account-key
    solvers:
      - dns01:
          route53:
            region: ${try(var.issuers.route53.region, "")}
EOF
}
