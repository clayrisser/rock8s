resource "kubectl_manifest" "letsencrypt-prod" {
  count     = (lookup(var.issuers, "letsencrypt", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
            ingressTemplate:
              metadata:
                annotations:
                  acme.cert-manager.io/http01-edit-in-place: 'true'
                  kubernetes.io/ingress.class: nginx
EOF
}

resource "kubectl_manifest" "letsencrypt-staging" {
  count     = (lookup(var.issuers, "letsencrypt", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
            ingressTemplate:
              metadata:
                annotations:
                  acme.cert-manager.io/http01-edit-in-place: 'true'
                  kubernetes.io/ingress.class: nginx
EOF
}
