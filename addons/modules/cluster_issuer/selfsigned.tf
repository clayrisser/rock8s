resource "kubectl_manifest" "selfsigned-issuer" {
  count     = (lookup(var.issuers, "selfsigned", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  ca:
    secretName: selfsigned-ca
EOF
}

resource "tls_private_key" "selfsigned-ca" {
  count     = (lookup(var.issuers, "selfsigned", null) != null && var.enabled) ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "selfsigned-ca" {
  count                 = (lookup(var.issuers, "selfsigned", null) != null && var.enabled) ? 1 : 0
  private_key_pem       = tls_private_key.selfsigned-ca[0].private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 24 * 356
  subject {
    common_name = "selfsigned-ca"
  }
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "cert_signing",
    "server_auth",
    "client_auth"
  ]
}

resource "kubectl_manifest" "selfsigned-secret" {
  count     = (lookup(var.issuers, "selfsigned", null) != null && var.enabled) ? 1 : 0
  yaml_body = <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: selfsigned-ca
  namespace: cert-manager 
type: kubernetes.io/tls
data:
  tls.crt: ${base64encode(tls_self_signed_cert.selfsigned-ca[0].cert_pem)}
  tls.key: ${base64encode(tls_private_key.selfsigned-ca[0].private_key_pem)}
EOF
  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}
