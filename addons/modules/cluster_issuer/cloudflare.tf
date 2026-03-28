resource "kubectl_manifest" "cloudflare-secret" {
  count     = (var.enabled && try(var.issuers.cloudflare.api_key != "" && var.issuers.cloudflare.email != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare
  namespace: ${var.namespace}
type: Opaque
stringData:
  cloudflare_api_key: '${try(var.issuers.cloudflare.api_key, "")}'
EOF
}

resource "kubectl_manifest" "cloudflare-prod" {
  count     = (var.enabled && try(var.issuers.cloudflare.api_key != "" && var.issuers.cloudflare.email != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: cloudflare-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            email: ${try(var.issuers.cloudflare.email, var.letsencrypt_email)}
            apiKeySecretRef:
              name: cloudflare
              key: cloudflare_api_key
EOF
  depends_on = [
    kubectl_manifest.cloudflare-secret
  ]
}

resource "kubectl_manifest" "cloudflare-staging" {
  count     = (var.enabled && try(var.issuers.cloudflare.api_key != "" && var.issuers.cloudflare.email != "", false)) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-staging
spec:
  acme:
    server: "https://acme-staging-v02.api.letsencrypt.org/directory"
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: cloudflare-staging-account-key
    solvers:
      - dns01:
          cloudflare:
            email: ${try(var.issuers.cloudflare.email, var.letsencrypt_email)}
            apiKeySecretRef:
              name: cloudflare
              key: cloudflare_api_key
EOF
  depends_on = [
    kubectl_manifest.cloudflare-secret
  ]
}
