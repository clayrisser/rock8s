resource "kubectl_manifest" "digitalocean-secret" {
  count     = (var.enabled && try(var.issuers.digitalocean.api_token != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean-dns
  namespace: ${var.namespace}
type: Opaque
stringData:
  access-token: '${try(var.issuers.digitalocean.api_token, "")}'
EOF
}

resource "kubectl_manifest" "digitalocean-prod" {
  count     = (var.enabled && try(var.issuers.digitalocean.api_token != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: digitalocean-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: digitalocean-prod-account-key
    solvers:
      - dns01:
          digitalocean:
            tokenSecretRef:
              name: digitalocean-dns
              key: access-token
EOF
  depends_on = [
    kubectl_manifest.digitalocean-secret
  ]
}

resource "kubectl_manifest" "digitalocean-staging" {
  count     = (var.enabled && try(var.issuers.digitalocean.api_token != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: digitalocean-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: digitalocean-staging-account-key
    solvers:
      - dns01:
          digitalocean:
            tokenSecretRef:
              name: digitalocean-dns
              key: access-token
EOF
  depends_on = [
    kubectl_manifest.digitalocean-secret
  ]
}
